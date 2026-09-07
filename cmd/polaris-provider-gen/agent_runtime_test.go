package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"testing"
)

func TestAgentRuntimePinsCodexCLIVersion(t *testing.T) {
	root := repoRoot(t)

	packageJSONPath := filepath.Join(root, "tools", "agent-runtime", "package.json")
	lockJSONPath := filepath.Join(root, "tools", "agent-runtime", "package-lock.json")

	packageBody, err := os.ReadFile(packageJSONPath)
	if err != nil {
		t.Fatalf("read %s: %v", packageJSONPath, err)
	}
	var pkg struct {
		DevDependencies map[string]string `json:"devDependencies"`
	}
	if err := json.Unmarshal(packageBody, &pkg); err != nil {
		t.Fatalf("parse %s: %v", packageJSONPath, err)
	}
	want, ok := pkg.DevDependencies["@openai/codex"]
	if !ok {
		t.Fatalf("%s missing devDependencies[\"@openai/codex\"]", packageJSONPath)
	}
	if !regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+([-.].+)?$`).MatchString(want) {
		t.Fatalf("%s devDependencies[\"@openai/codex\"] must be an exact version, got %q", packageJSONPath, want)
	}

	lockBody, err := os.ReadFile(lockJSONPath)
	if err != nil {
		t.Fatalf("read %s: %v", lockJSONPath, err)
	}
	var lock struct {
		Packages map[string]struct {
			Version string `json:"version"`
		} `json:"packages"`
		Dependencies map[string]struct {
			Version string `json:"version"`
		} `json:"dependencies"`
		DevDepsLegacy map[string]struct {
			Version string `json:"version"`
		} `json:"devDependencies"`
	}
	if err := json.Unmarshal(lockBody, &lock); err != nil {
		t.Fatalf("parse %s: %v", lockJSONPath, err)
	}

	got := ""
	if entry, ok := lock.Packages["node_modules/@openai/codex"]; ok {
		got = entry.Version
	} else if entry, ok := lock.Dependencies["@openai/codex"]; ok {
		got = entry.Version
	} else if entry, ok := lock.DevDepsLegacy["@openai/codex"]; ok {
		got = entry.Version
	}

	if got == "" {
		t.Fatalf("%s missing @openai/codex entry", lockJSONPath)
	}
	if got != want {
		t.Fatalf("agent runtime codex pin mismatch: %s wants %q but %s locks %q", packageJSONPath, want, lockJSONPath, got)
	}
}
