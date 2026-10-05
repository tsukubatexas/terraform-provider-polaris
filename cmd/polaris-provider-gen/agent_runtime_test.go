package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"testing"
)

type agentRuntimePackageJSON struct {
	DevDependencies map[string]string `json:"devDependencies"`
}

type agentRuntimePackageLock struct {
	LockfileVersion int `json:"lockfileVersion"`
	Packages        map[string]struct {
		Version              string            `json:"version"`
		DevDependencies      map[string]string `json:"devDependencies"`
		OptionalDependencies map[string]string `json:"optionalDependencies"`
		Bin                  map[string]string `json:"bin"`
	} `json:"packages"`
}

func TestAgentRuntimeCodexIsPinnedAndLockMatches(t *testing.T) {
	root := repoRoot(t)

	pkgPath := filepath.Join(root, "tools", "agent-runtime", "package.json")
	pkgBody, err := os.ReadFile(pkgPath)
	if err != nil {
		t.Fatalf("read %s: %v", pkgPath, err)
	}
	var pkg agentRuntimePackageJSON
	if err := json.Unmarshal(pkgBody, &pkg); err != nil {
		t.Fatalf("parse %s: %v", pkgPath, err)
	}

	codexVersion, ok := pkg.DevDependencies["@openai/codex"]
	if !ok {
		t.Fatalf("%s missing devDependencies['@openai/codex']", pkgPath)
	}
	if codexVersion == "" {
		t.Fatalf("%s has empty devDependencies['@openai/codex']", pkgPath)
	}
	semverExact := regexp.MustCompile(`^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$`)
	if !semverExact.MatchString(codexVersion) {
		t.Fatalf("%s devDependencies['@openai/codex'] must be an exact version (no ^/~). got %q", pkgPath, codexVersion)
	}

	lockPath := filepath.Join(root, "tools", "agent-runtime", "package-lock.json")
	lockBody, err := os.ReadFile(lockPath)
	if err != nil {
		t.Fatalf("read %s: %v", lockPath, err)
	}
	var lock agentRuntimePackageLock
	if err := json.Unmarshal(lockBody, &lock); err != nil {
		t.Fatalf("parse %s: %v", lockPath, err)
	}

	if lock.LockfileVersion < 2 {
		t.Fatalf("%s lockfileVersion too old: %d", lockPath, lock.LockfileVersion)
	}

	rootPkg, ok := lock.Packages[""]
	if !ok {
		t.Fatalf("%s missing packages['']", lockPath)
	}
	if got := rootPkg.DevDependencies["@openai/codex"]; got != codexVersion {
		t.Fatalf("%s packages[''].devDependencies['@openai/codex'] got %q want %q", lockPath, got, codexVersion)
	}

	codexPkg, ok := lock.Packages["node_modules/@openai/codex"]
	if !ok {
		t.Fatalf("%s missing packages['node_modules/@openai/codex']", lockPath)
	}
	if codexPkg.Version != codexVersion {
		t.Fatalf("%s packages['node_modules/@openai/codex'].version got %q want %q", lockPath, codexPkg.Version, codexVersion)
	}
	if _, ok := codexPkg.Bin["codex"]; !ok {
		t.Fatalf("%s packages['node_modules/@openai/codex'].bin missing 'codex'", lockPath)
	}

	for name, ref := range codexPkg.OptionalDependencies {
		if name == "" || ref == "" {
			t.Fatalf("%s has empty optional dependency entry: %q=%q", lockPath, name, ref)
		}
		wantPrefix := "npm:@openai/codex@" + codexVersion + "-"
		if len(ref) <= len(wantPrefix) || ref[:len(wantPrefix)] != wantPrefix {
			t.Fatalf("%s optional dependency %q should start with %q, got %q", lockPath, name, wantPrefix, ref)
		}
	}
}
