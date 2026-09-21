package main

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/tsukubatexas/terraform-provider-polaris/internal/generated"
)

func TestCachedSpecsMatchGeneratedOperations(t *testing.T) {
	tag := generated.ReleaseTag
	if tag == "" {
		t.Fatal("internal/generated.ReleaseTag is empty")
	}

	repoRoot, err := filepath.Abs(filepath.Join(".", "..", ".."))
	if err != nil {
		t.Fatalf("repo root: %v", err)
	}

	ops := map[string]generatedOperation{}
	for _, source := range defaultSpecs {
		filename := filepath.Join(repoRoot, "specs", tag, filepath.FromSlash(source.Path))
		body, err := os.ReadFile(filename)
		if err != nil {
			if source.Required {
				t.Fatalf("read required cached spec %s: %v", filename, err)
			}
			continue
		}

		specOps, err := parseSpec(source.Path, body)
		if err != nil {
			t.Fatalf("parseSpec(%s): %v", source.Path, err)
		}
		for _, op := range specOps {
			if existing, ok := ops[op.ID]; ok {
				op.ID = stableOperationID(op.Spec, op.Method, op.Path)
				if _, ok := ops[op.ID]; ok {
					t.Fatalf("duplicate operation id %q from %s and %s", op.ID, existing.Spec, op.Spec)
				}
			}
			ops[op.ID] = op
		}
	}

	if len(ops) == 0 {
		t.Fatalf("no operations were parsed from cached specs for %s", tag)
	}
	if got, want := len(ops), len(generated.Operations); got != want {
		t.Fatalf("cached specs generated %d operations, but internal/generated has %d for %s", got, want, tag)
	}

	for id, expected := range ops {
		got, ok := generated.Operations[id]
		if !ok {
			t.Fatalf("internal/generated missing operation_id %q from cached specs", id)
		}
		if got.Spec != expected.Spec || got.Method != expected.Method || got.Path != expected.Path {
			t.Fatalf("operation %q mismatch: got (spec=%q method=%q path=%q) want (spec=%q method=%q path=%q)",
				id, got.Spec, got.Method, got.Path, expected.Spec, expected.Method, expected.Path,
			)
		}
	}
}
