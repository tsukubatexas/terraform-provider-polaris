# ADR 0016: Harden Agent Runtime Pinning and HTTP Body Limits

Date: 2026-10-26

Status: Accepted

## Context

This repository relies on a pinned Codex CLI runtime under `tools/agent-runtime` for autonomous GitHub Actions repair loops. If the NPM pin drifts (ranges, mismatched lockfiles, missing integrity), autonomous workflows can become non-reproducible or insecure.

The generator and provider also fetch and read HTTP responses (OpenAPI specs, GitHub API, Polaris API, OAuth token exchange). Unbounded `io.ReadAll` reads can cause excessive memory usage and increase the risk of logging large, potentially sensitive error bodies.

We cannot modify `.github/workflows/*` from the autonomous self-improvement loop, so guardrails should live in scripts and tests that workflows already invoke.

## Decision

- Add `scripts/check_agent_runtime_pins.sh` to verify `tools/agent-runtime/package.json` and `tools/agent-runtime/package-lock.json` keep `@openai/codex` pinned to an exact `x.y.z` version with registry `resolved` URLs and `integrity` fields, including the platform-specific optional dependency pins.
- Update `scripts/self_improve.sh` to run `scripts/check_agent_runtime_pins.sh` and `scripts/check_adr_updates.sh` as part of the loop's pre/post checks.
- Introduce explicit HTTP response body size limits:
  - Generator: limit GitHub API error bodies and spec downloads.
  - Provider client: limit response bodies (including OAuth token responses), returning clear errors with truncated previews.

## Consequences

- Autonomous runs fail fast when the agent runtime pin becomes inconsistent or insecure, without requiring workflow edits.
- Generator/provider HTTP reads are bounded, reducing DoS risk from unexpectedly large responses and keeping error output manageable.
- If a future Polaris release ships unusually large OpenAPI specs or responses, limits may need adjustment (with a companion ADR update).

