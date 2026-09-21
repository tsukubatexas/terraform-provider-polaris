# ADR 0016: Validate Agent Runtime Pin and Spec Cache Consistency

Date: 2026-09-21

Status: Accepted

## Context

This repository runs autonomous repair and self-improvement loops in GitHub Actions. Those loops rely on a pinned Node-based agent runtime under `tools/agent-runtime/` and on generated provider artifacts derived from Apache Polaris OpenAPI specs cached under `specs/`.

If the agent runtime dependency pin drifts (e.g., `package.json` and `package-lock.json` disagree, or ranges are introduced), CI can become non-reproducible and autonomous loops can change behavior unexpectedly. If generated operation metadata drifts from the cached spec inputs, the provider can silently diverge from Polaris behavior, and generator regressions can go unnoticed until runtime.

The CI toolchain is Go 1.24 today, so dependency upgrades must remain compatible with that toolchain.

## Decision

- Add a script guard to assert `tools/agent-runtime` keeps `@openai/codex` pinned to an exact version and that `package-lock.json` matches the pin.
- Add a generator regression test that re-parses the cached specs for `internal/generated.ReleaseTag` and verifies the computed operation registry matches `internal/generated.Operations`.
- Keep Go module upgrades within the Go 1.24 compatibility window, upgrading the Terraform Plugin SDK only to the newest release that still supports Go 1.24.

## Consequences

- Agent runtime updates become intentional and reviewable: the lockfile pin must stay exact and internally consistent.
- Generator/provider drift is detected early: cached spec inputs and generated operation metadata must agree.
- Terraform Plugin SDK upgrades beyond the Go 1.24 window are deferred until the repo toolchain is upgraded.

