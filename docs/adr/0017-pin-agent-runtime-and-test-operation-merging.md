# ADR 0017: Pin Agent Runtime and Test Operation Merging

Date: 2026-06-07

Status: Accepted

## Context

This repository runs autonomous maintenance loops in GitHub Actions (self-improvement, repair, and infra loops).
Those loops rely on a pinned OpenAI Codex CLI runtime under `tools/agent-runtime` so that behavior is reproducible and
breakage from upstream dependency drift is minimized.

The provider generator (`cmd/polaris-provider-gen`) also has a critical behavior: it must merge operations from multiple
Polaris OpenAPI specs, gracefully handling duplicate `operationId` values by falling back to a stable, derived ID.
This merge behavior needs explicit unit tests so regressions are detected before they affect generated provider behavior.

## Decision

- Keep `tools/agent-runtime` pinned to a specific `@openai/codex` version via `package.json` and `package-lock.json`.
- Refactor the generator operation merge logic into a dedicated `mergeOperations` helper and add unit tests for:
  - Resolving duplicate `operationId` values into stable fallback IDs.
  - Failing fast when the fallback ID also collides.
- Add a provider-side invariant test ensuring every generated operation is well-formed (supported HTTP method, non-empty
  spec, leading-slash path, and matching map key/ID).

## Consequences

- Autonomous workflows continue to use a pinned, reviewable agent runtime dependency set.
- Generator behavior around duplicate operations becomes harder to regress silently.
- Provider tests fail early if generated operation metadata becomes malformed, reducing the chance of publishing a broken
  registry.

