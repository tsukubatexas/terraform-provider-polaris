package provider

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"

	"github.com/hashicorp/terraform-plugin-sdk/v2/helper/schema"
)

func stringMap(d *schema.ResourceData, key string) map[string]string {
	raw, ok := d.GetOk(key)
	if !ok {
		return map[string]string{}
	}
	result := map[string]string{}
	for k, v := range raw.(map[string]interface{}) {
		result[k] = fmt.Sprint(v)
	}
	return result
}

func intSet(d *schema.ResourceData, key string, fallback []int) map[int]struct{} {
	raw, ok := d.GetOk(key)
	if !ok {
		result := map[int]struct{}{}
		for _, code := range fallback {
			result[code] = struct{}{}
		}
		return result
	}
	result := map[int]struct{}{}
	for _, v := range raw.([]interface{}) {
		result[v.(int)] = struct{}{}
	}
	return result
}

func checkStatus(status int, accepted map[int]struct{}, body string) error {
	if _, ok := accepted[status]; ok {
		return nil
	}
	return fmt.Errorf("unexpected HTTP status %d: %s", status, safeHTTPBody([]byte(body)))
}

func safeHTTPBody(body []byte) string {
	const maxBody = 4096
	redacted := redactSecrets(body)
	if len(redacted) <= maxBody {
		return string(redacted)
	}
	return string(redacted[:maxBody]) + "... [truncated]"
}

func stableID(parts ...string) string {
	sum := sha256.Sum256([]byte(strings.Join(parts, "\x00")))
	return hex.EncodeToString(sum[:])[:24]
}

func extractJSONPath(body, path string) (string, error) {
	if path == "" {
		return "", nil
	}
	var value interface{}
	if err := json.Unmarshal([]byte(body), &value); err != nil {
		return "", err
	}
	current := value
	for _, part := range strings.Split(path, ".") {
		obj, ok := current.(map[string]interface{})
		if !ok {
			return "", fmt.Errorf("id_attribute %q could not traverse %q", path, part)
		}
		current, ok = obj[part]
		if !ok {
			return "", fmt.Errorf("id_attribute %q missing %q", path, part)
		}
	}
	return fmt.Sprint(current), nil
}

var secretKeys = map[string]struct{}{
	"access_token":  {},
	"refresh_token": {},
	"client_secret": {},
	"token":         {},
	"authorization": {},
	"password":      {},
	"secret":        {},
	"api_key":       {},
	"apikey":        {},
	"private_key":   {},
	"privatekey":    {},
	"id_token":      {},
	"bearer_token":  {},
	"session_token": {},
	"sessiontoken":  {},
	"refresh-token": {},
	"access-token":  {},
	"client-secret": {},
}

var (
	bearerTokenPattern    = regexp.MustCompile(`(?i)\bBearer\s+[A-Za-z0-9._~+/=-]+\b`)
	querySecretPattern    = regexp.MustCompile(`(?i)\b(access_token|refresh_token|client_secret|token|password|secret|api_key|apikey|id_token)=([^&\s]+)`)
	jsonStringSecretField = regexp.MustCompile(`(?i)("(access_token|refresh_token|client_secret|token|password|secret|api_key|apikey|id_token)"\s*:\s*")([^"]*)(")`)
)

func redactSecrets(body []byte) []byte {
	const maxJSONRedact = 64 * 1024
	if len(body) <= maxJSONRedact && json.Valid(body) {
		var value interface{}
		if err := json.Unmarshal(body, &value); err == nil {
			value = redactJSON(value)
			if redacted, err := json.Marshal(value); err == nil {
				return redacted
			}
		}
	}
	text := string(body)
	text = bearerTokenPattern.ReplaceAllString(text, "Bearer [REDACTED]")
	text = querySecretPattern.ReplaceAllString(text, `$1=[REDACTED]`)
	text = jsonStringSecretField.ReplaceAllString(text, `$1[REDACTED]$4`)
	return []byte(text)
}

func redactJSON(value interface{}) interface{} {
	switch typed := value.(type) {
	case map[string]interface{}:
		out := map[string]interface{}{}
		for key, v := range typed {
			normalized := strings.ToLower(strings.TrimSpace(key))
			if _, ok := secretKeys[normalized]; ok {
				out[key] = "[REDACTED]"
				continue
			}
			out[key] = redactJSON(v)
		}
		return out
	case []interface{}:
		out := make([]interface{}, 0, len(typed))
		for _, v := range typed {
			out = append(out, redactJSON(v))
		}
		return out
	default:
		return value
	}
}
