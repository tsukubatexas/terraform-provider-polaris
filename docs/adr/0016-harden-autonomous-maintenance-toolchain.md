# ADR 0016: Harden Autonomous Maintenance Toolchain

Date: 2026-06-07

Status: Accepted

## Context

The repository is intended to maintain a Terraform provider for Apache Polaris with scheduled autonomous update, test, release, cleanup and self-improvement workflows.

The June 2026 maintenance runs showed three separate failure modes:

- The weekly self-improvement workflow failed when the OpenAI quota was exhausted, even though `make generate`, `make fmt`, `make test` and `make build` were already green.
- Dependabot pull requests for GitHub Actions and agent runtime dependencies were blocked by the ADR guard because they touched workflow or lock files without adding an ADR.
- A Go dependency update required Go 1.25.8, while CI and agent jobs were pinned to `golang:1.24-bookworm`.

These failures did not indicate a broken Terraform provider, but they made the autonomous maintenance layer noisy and less reliable.

## Decision

Harden autonomous maintenance as follows:

- Upgrade the provider toolchain to Go 1.25.8 and use Go 1.26 container jobs for long-running agent workflows.
- Upgrade `github.com/hashicorp/terraform-plugin-sdk/v2` to 2.40.1 and keep `make generate fmt test build` as the provider health gate.
- Upgrade the pinned Codex CLI runtime to `@openai/codex` 0.135.0.
- Upgrade pinned GitHub Actions to current Node-24-compatible major versions while preserving immutable full-SHA pins.
- Allow Dependabot-only dependency PRs to pass `scripts/check_adr_updates.sh` without adding a new ADR when the changed files are limited to Go modules, agent runtime package files, or workflow action references.
- Keep ADRs required for manual or agent-authored durable changes to provider code, generator code, workflows, scripts, release behavior, examples, or test strategy.
- Make `scripts/self_improve.sh` and `scripts/quarterly_cleanup.sh` treat agent runtime failure as a skipped improvement pass when baseline checks are already green and no repository changes were produced.
- Keep agent runtime failure fatal when baseline checks are failing or when the agent leaves repository changes behind.

## Consequences

- A healthy provider build no longer turns red just because an optional autonomous improvement agent cannot run.
- Dependabot can keep low-risk dependency and action pins moving without being blocked by ADR bureaucracy.
- Manual workflow and agent-loop changes still need durable explanation in ADRs.
- The Go toolchain is aligned with current Terraform Plugin SDK requirements.
- GitHub Actions are prepared for the Node.js 20 deprecation window.
- The repository remains autonomous, but the automation is now less brittle and more explicit about which failures are provider failures versus optional improvement failures.
