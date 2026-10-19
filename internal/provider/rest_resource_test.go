package provider

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestRestResourceLifecycleUsesPhasesAndIDAttribute(t *testing.T) {
	var createRequests int
	var readRequests int
	var updateRequests int
	var deleteRequests int

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.Method == http.MethodPost && r.URL.Path == "/catalogs":
			createRequests++
			if got := r.Header.Get("Authorization"); got != "Bearer test-token" {
				t.Fatalf("create authorization got %q", got)
			}
			if got := r.Header.Get("Content-Type"); got != "application/json" {
				t.Fatalf("create content-type got %q", got)
			}
			body, _ := io.ReadAll(r.Body)
			if strings.TrimSpace(string(body)) != `{"name":"risk"}` {
				t.Fatalf("create body got %q", string(body))
			}
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusCreated)
			_ = json.NewEncoder(w).Encode(map[string]any{
				"catalog": map[string]string{"name": "risk"},
			})
		case r.Method == http.MethodGet && r.URL.Path == "/catalogs/risk":
			readRequests++
			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode(map[string]string{"name": "risk"})
		case r.Method == http.MethodPatch && r.URL.Path == "/catalogs/risk":
			updateRequests++
			w.WriteHeader(http.StatusNoContent)
		case r.Method == http.MethodDelete && r.URL.Path == "/catalogs/risk":
			deleteRequests++
			w.WriteHeader(http.StatusNoContent)
		default:
			t.Fatalf("unexpected request %s %s", r.Method, r.URL.Path)
		}
	}))
	defer server.Close()

	client, err := newClient(clientConfig{Endpoint: server.URL, Token: "test-token"})
	if err != nil {
		t.Fatalf("newClient: %v", err)
	}

	resource := restResource()
	data := resource.Data(nil)
	if err := data.Set("create_method", "POST"); err != nil {
		t.Fatalf("set create_method: %v", err)
	}
	if err := data.Set("create_path", "/catalogs"); err != nil {
		t.Fatalf("set create_path: %v", err)
	}
	if err := data.Set("read_method", "GET"); err != nil {
		t.Fatalf("set read_method: %v", err)
	}
	if err := data.Set("read_path", "/catalogs/{catalogName}"); err != nil {
		t.Fatalf("set read_path: %v", err)
	}
	if err := data.Set("update_method", "PATCH"); err != nil {
		t.Fatalf("set update_method: %v", err)
	}
	if err := data.Set("update_path", "/catalogs/{catalogName}"); err != nil {
		t.Fatalf("set update_path: %v", err)
	}
	if err := data.Set("delete_method", "DELETE"); err != nil {
		t.Fatalf("set delete_method: %v", err)
	}
	if err := data.Set("delete_path", "/catalogs/{catalogName}"); err != nil {
		t.Fatalf("set delete_path: %v", err)
	}
	if err := data.Set("path_params", map[string]any{"catalogName": "risk"}); err != nil {
		t.Fatalf("set path_params: %v", err)
	}
	if err := data.Set("body", `{"name":"risk"}`); err != nil {
		t.Fatalf("set body: %v", err)
	}
	if err := data.Set("id_attribute", "catalog.name"); err != nil {
		t.Fatalf("set id_attribute: %v", err)
	}

	if diags := resourceRestCreate(context.Background(), data, client); len(diags) > 0 {
		t.Fatalf("create diags: %#v", diags)
	}
	if data.Id() != "risk" {
		t.Fatalf("id got %q want %q", data.Id(), "risk")
	}
	if got, ok := data.GetOk("status_code"); !ok || got.(int) != http.StatusOK {
		t.Fatalf("status_code got %#v want %d", got, http.StatusOK)
	}

	if diags := resourceRestUpdate(context.Background(), data, client); len(diags) > 0 {
		t.Fatalf("update diags: %#v", diags)
	}

	if diags := resourceRestDelete(context.Background(), data, client); len(diags) > 0 {
		t.Fatalf("delete diags: %#v", diags)
	}
	if data.Id() != "" {
		t.Fatalf("id should be cleared after delete, got %q", data.Id())
	}

	if createRequests != 1 || updateRequests != 1 || deleteRequests != 1 {
		t.Fatalf("requests got create=%d update=%d delete=%d", createRequests, updateRequests, deleteRequests)
	}
	if readRequests < 2 {
		t.Fatalf("read requests got %d want >= 2 (create/read + update/read)", readRequests)
	}
}
