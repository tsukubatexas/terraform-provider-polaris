package provider

import (
	"strings"
	"testing"
)

func TestSafeHTTPBodyRedactsJSONSecrets(t *testing.T) {
	body := []byte(`{"access_token":"abc","nested":{"client_secret":"def"},"token":123,"ok":"value"}`)
	got := safeHTTPBody(body)
	for _, secret := range []string{"abc", "def", "123"} {
		if strings.Contains(got, secret) {
			t.Fatalf("expected secret %q to be redacted, got %q", secret, got)
		}
	}
	if !strings.Contains(got, "[REDACTED]") {
		t.Fatalf("expected redaction marker, got %q", got)
	}
	if !strings.Contains(got, `"ok":"value"`) {
		t.Fatalf("expected non-secret field to remain, got %q", got)
	}
}

func TestSafeHTTPBodyRedactsBearerAndQuerySecrets(t *testing.T) {
	body := []byte("Authorization: Bearer abc.def.ghi\nclient_secret=supersecret&foo=bar\n")
	got := safeHTTPBody(body)
	if strings.Contains(got, "abc.def.ghi") || strings.Contains(got, "supersecret") {
		t.Fatalf("expected secrets to be redacted, got %q", got)
	}
	if !strings.Contains(got, "Bearer [REDACTED]") {
		t.Fatalf("expected bearer token to be redacted, got %q", got)
	}
	if !strings.Contains(got, "client_secret=[REDACTED]") {
		t.Fatalf("expected query secret to be redacted, got %q", got)
	}
}
