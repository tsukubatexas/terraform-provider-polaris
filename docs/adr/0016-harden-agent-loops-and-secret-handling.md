# ADR 0016: Harden Agent Loops and Secret Handling

Date: 2026-11-02

Status: Accepted

## Context

This repository is intentionally autonomous: workflows and scripts regenerate the provider from upstream Polaris OpenAPI specs and may invoke an agentic repair loop.

Two maintenance gaps were identified:

- The self-improvement loop (`scripts/self_improve.sh`) was not running the same hardening gates as CI, which increases the chance of “green locally, red in CI” drift for autonomous changes.
- The generic REST resource/data source allow arbitrary headers. If a user supplies `Authorization` (or other secrets) via `headers`, those values can end up in Terraform state unless the attribute is marked sensitive.

Go dependency updates also need to respect the Go toolchain version pinned by CI containers.

## Decision

- Mark `headers` as `Sensitive` in both `polaris_rest_resource` and `polaris_rest_call`.
- Update the generated Terraform Registry-style documentation to reflect that `headers` is sensitive.
- Add a lightweight pin-consistency check for `tools/agent-runtime` to ensure `package.json`, `package-lock.json`, and the vendored module agree on the pinned `@openai/codex` version.
- Align `scripts/self_improve.sh` checks with the CI gate scripts so autonomous maintenance runs converge on the same definition of “green”.
- Upgrade `github.com/hashicorp/terraform-plugin-sdk/v2` to the newest release compatible with the repository’s Go toolchain.

## Consequences

- Header values supplied in Terraform configuration are treated as sensitive and are no longer displayed in plans/state output, reducing accidental secret exposure risk.
- Autonomous maintenance loops fail earlier when they would later fail CI, reducing wasted rounds.
- Codex CLI runtime pins are less likely to drift silently, improving reproducibility of agentic repair workflows.
- Some dependency updates may be deferred until CI upgrades the Go toolchain (for example, newer `terraform-plugin-sdk` releases that require Go >= 1.25).

