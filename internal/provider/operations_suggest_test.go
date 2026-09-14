package provider

import (
	"fmt"
	"sort"
	"strings"
	"testing"

	"github.com/tsukubatexas/terraform-provider-polaris/internal/generated"
)

func TestOperationByIDSuggestsCloseMatch(t *testing.T) {
	ids := make([]string, 0, len(generated.Operations))
	for id := range generated.Operations {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	if len(ids) == 0 {
		t.Fatal("no generated operations loaded")
	}

	target := ids[0]
	misspelled := target
	if len(misspelled) > 1 {
		misspelled = misspelled[:len(misspelled)-1]
	} else {
		misspelled = misspelled + "x"
	}

	_, err := operationByID(misspelled)
	if err == nil {
		t.Fatalf("expected error for unknown operation_id %q", misspelled)
	}
	msg := err.Error()
	if !strings.Contains(msg, "did you mean") {
		t.Fatalf("expected suggestion in error, got %q", msg)
	}
	if !strings.Contains(msg, fmt.Sprintf("%q", target)) {
		t.Fatalf("expected error to include suggestion %q, got %q", target, msg)
	}
}
