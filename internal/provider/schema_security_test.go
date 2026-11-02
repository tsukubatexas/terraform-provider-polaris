package provider

import "testing"

func TestHeadersAreSensitiveInSchemas(t *testing.T) {
	rest := restResource()
	if rest.Schema["headers"] == nil || !rest.Schema["headers"].Sensitive {
		t.Fatalf("polaris_rest_resource headers must be marked Sensitive")
	}

	call := restCallDataSource()
	if call.Schema["headers"] == nil || !call.Schema["headers"].Sensitive {
		t.Fatalf("polaris_rest_call headers must be marked Sensitive")
	}
}
