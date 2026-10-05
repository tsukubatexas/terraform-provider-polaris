package provider

import (
	"strings"
	"testing"
)

func TestSafeHTTPBodyRedactsJSONSecrets(t *testing.T) {
	body := []byte(`{"access_token":"abc","nested":{"client_secret":"shh"},"items":[{"token":"t"}]}`)
	got := safeHTTPBody(body)
	for _, wantAbsent := range []string{`"access_token":"abc"`, `"client_secret":"shh"`, `"token":"t"`} {
		if strings.Contains(got, wantAbsent) {
			t.Fatalf("safeHTTPBody leaked secret value %q: %s", wantAbsent, got)
		}
	}
	if strings.Count(got, "[REDACTED]") != 3 {
		t.Fatalf("expected 3 redactions, got %d: %s", strings.Count(got, "[REDACTED]"), got)
	}
}
