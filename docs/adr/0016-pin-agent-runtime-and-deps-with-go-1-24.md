# ADR 0016: Pin agent runtime and dependencies within Go 1.24

Date: 2026-10-19

Status: Accepted

## Context

This provider is maintained by autonomous GitHub workflows and repair loops that depend on a pinned Codex CLI runtime under `tools/agent-runtime/`.

The repository also tracks a stable Go toolchain (`go 1.24.0`) and runs `make generate fmt test build` in CI. Some upstream dependency versions now require newer Go toolchains (for example, `github.com/hashicorp/terraform-plugin-sdk/v2@v2.40.x` and newer `golang.org/x/*` releases), which would break the current build constraints.

Separately, the generic `polaris_rest_resource` is intended to support a broad set of OpenAPI-backed operations. Most unit tests focused on low-level helpers and the OpenAPI operation registry, leaving a gap in lifecycle coverage for create/read/update/delete phase wiring and `id_attribute` extraction.

## Decision

- Keep the autonomous agent runtime pinned by upgrading `@openai/codex` in `tools/agent-runtime/` while continuing to rely on lockfile pinning for reproducibility.
- Modernize Go dependencies to the newest Terraform Plugin SDK release that still supports Go 1.24 (`v2.39.0`), and allow the indirect dependency graph to follow from that constraint.
- Add a focused unit test covering `polaris_rest_resource` lifecycle phase wiring and `id_attribute` extraction using an `httptest` server.

## Consequences

- The agent runtime stays explicitly pinned and easier to update without touching workflow files.
- Dependency upgrades remain compatible with `go 1.24.x` until a separate maintainer-reviewed PR updates the Go toolchain and workflows.
- Provider lifecycle behavior for the generic REST resource is better protected against regressions.

## Findings

- Dependency versions reported as "latest" by tooling may be incompatible with the repo's Go toolchain; validate candidate upgrades against Go 1.24 before adopting them.

