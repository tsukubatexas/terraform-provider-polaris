# Agent Runtime (Pinned)

This directory pins the autonomous repair loop runtime dependencies used by GitHub Actions.

Goals:
- Keep the runtime deterministic (no floating semver ranges).
- Keep the GitHub Action compatible with a known-good `@openai/codex` version.

## Updating `@openai/codex`

1. Update `tools/agent-runtime/package.json` to the desired exact version.
2. Update `tools/agent-runtime/package-lock.json` (and only that lockfile) to match.
3. Run `go test ./...` to ensure the pin matches what the repository expects.

This repo intentionally treats the `@openai/codex` version as an explicit, reviewed upgrade
instead of a continuously-floating dependency.

