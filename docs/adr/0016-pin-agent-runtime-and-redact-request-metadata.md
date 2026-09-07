# ADR 0016: Pin Agent Runtime and Redact Request Metadata

Date: 2026-09-07

Status: Accepted

## Context

This repository uses an autonomous repair loop that depends on a pinned `@openai/codex` CLI runtime under `tools/agent-runtime`. A drifting semver range or a desynced lockfile can silently change the repair environment and make CI behavior non-reproducible.

Separately, the provider offers generic REST primitives (`polaris_rest_resource` and `polaris_rest_call`) that accept user-supplied request metadata. Users may pass tokens or other secrets in headers or query strings. Terraform should treat those values as sensitive to reduce accidental disclosure in plans, logs, and state diffs.

## Decision

- Add a Go unit test that asserts `tools/agent-runtime/package.json` pins `@openai/codex` to an exact version and that `tools/agent-runtime/package-lock.json` locks the same version.
- Document the pinning workflow in `tools/agent-runtime/README.md`.
- Mark `headers` and `query_params` as `Sensitive` in the generic REST resource and data source schemas, and update generated Terraform Registry docs to match.

## Consequences

- Autonomous repair tooling upgrades become explicit, reviewable changes instead of accidental drift.
- Terraform CLI output is less likely to echo secrets supplied via headers or query strings.
- The provider still stores sensitive values in state; consumers must continue to protect Terraform state and logs.

