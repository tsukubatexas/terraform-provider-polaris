package provider

import "testing"

func TestRestSchemasMarkUserSuppliedHeadersAndQueryParamsSensitive(t *testing.T) {
	resource := restResource()
	if resource.Schema["headers"] == nil || !resource.Schema["headers"].Sensitive {
		t.Fatalf("rest resource headers should be marked sensitive")
	}
	if resource.Schema["query_params"] == nil || !resource.Schema["query_params"].Sensitive {
		t.Fatalf("rest resource query_params should be marked sensitive")
	}

	dataSource := restCallDataSource()
	if dataSource.Schema["headers"] == nil || !dataSource.Schema["headers"].Sensitive {
		t.Fatalf("rest call headers should be marked sensitive")
	}
	if dataSource.Schema["query_params"] == nil || !dataSource.Schema["query_params"].Sensitive {
		t.Fatalf("rest call query_params should be marked sensitive")
	}
}
