# ADR 0010: Harden agent runtime pinning and redact HTTP error secrets

Date: 2026-10-05

Status: Accepted

## Context

This repo relies on autonomous GitHub Action repair loops that execute Codex via `npx --prefix tools/agent-runtime codex ...`.

Two issues make long-term maintenance brittle:

- A drifting `tools/agent-runtime` dependency graph can silently change the agent runtime behavior (CLI flags, auth flows, defaults), causing workflows to fail at unpredictable times.
- Provider error messages can include raw HTTP response bodies. If Polaris (or any upstream) returns a JSON body containing credentials/tokens, Terraform diagnostics could inadvertently surface secrets in logs.

Additionally, the generator/provider should have small, offline-focused tests that validate expected parsing and normalization behavior without relying on live Polaris infrastructure.

## Decision

- Add a Go test that enforces:
  - `tools/agent-runtime/package.json` pins `@openai/codex` to an exact version (no `^`/`~` ranges).
  - `tools/agent-runtime/package-lock.json` matches the pinned version and exposes the `codex` binary entry.
- Redact common secret-bearing JSON fields (for example `access_token`, `refresh_token`, `client_secret`) inside `safeHTTPBody` before including bodies in error messages.
- Extend generator parsing tests to assert that summaries are trimmed and stable fallback operation IDs are generated for operations that omit `operationId`.

## Consequences

- Pros:
  - Agent runtime drift is detected by `go test ./...` without requiring Node/npm in the test environment.
  - Terraform diagnostics are less likely to leak tokens or secrets in failure scenarios.
  - Generator parsing behavior is covered by lightweight fixture-based tests.
- Cons:
  - Redaction can reduce debuggability for some upstream auth failures; the provider must rely on non-secret fields (HTTP status, non-sensitive messages) for troubleshooting.

