# ADR 0010: Redact secrets and add dependency guardrails

Date: 2026-09-14

Status: Accepted

## Context

This repo is maintained by autonomous workflows and includes a generic REST client
and OAuth client-credentials flow. Provider errors may include portions of HTTP
response bodies (for example token endpoint failures), which can contain
credentials or bearer tokens.

The repo also vendors a pinned agent runtime (`tools/agent-runtime`) and relies
on regular dependency refreshes to stay secure, but updates must remain compatible
with the currently available Go toolchain in CI.

## Decision

- Redact common secret fields and bearer tokens from `safeHTTPBody` before the
  body is included in errors.
- Improve unknown `operation_id` errors with a small set of suggestions to reduce
  user friction when operation IDs change across Polaris releases.
- Add Dependabot configuration for Go modules and the pinned agent runtime.
- Add a local script (`scripts/check_agent_runtime_pinned.sh`) to verify that
  `tools/agent-runtime` pins are consistent across `package.json`,
  `package-lock.json`, and vendored `node_modules`.
- Upgrade Go dependencies within the constraints of the current Go toolchain.

## Consequences

- Provider errors should no longer echo bearer tokens or OAuth secrets in common
  failure cases.
- Dependency refreshes are more likely to arrive as Conventional Commit messages
  (`chore(deps): ...`) suitable for Release Please.
- Some upstream dependency versions cannot be adopted until CI/toolchain is
  updated; for example, `terraform-plugin-sdk/v2` v2.40+ requires Go >= 1.25,
  so the repo remains on v2.39.x while Go is 1.24.x.

## Findings

- `github.com/hashicorp/terraform-plugin-sdk/v2` v2.40.0+ requires a newer Go
  version than the currently available toolchain in this repo's CI environment.

