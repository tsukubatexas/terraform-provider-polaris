# ADR 0016: Harden Autonomous PR Hygiene Selection

Date: 2026-07-01

Status: Accepted

## Context

This repository uses `scripts/autonomous_pr_hygiene.sh` to close stale or superseded bot-managed pull requests so the autonomous maintenance queue does not accumulate.

The script decides which pull requests are "autonomous" via a jq predicate and then applies additional filters (stale, duplicated family, failed checks). That predicate previously appeared in multiple jq programs inside the same script, which risked subtle drift over time (for example: a pull request being eligible for stale closure but excluded from failed-check closure, or vice-versa).

The script also accepts numeric environment variables to control time windows. Misconfigured values should fail fast with clear errors instead of producing confusing jq or arithmetic failures.

## Decision

- Generate a single "prepared" autonomous pull request list in jq and reuse it for both stale/duplicate selection and failed-check scanning.
- Validate `PR_HYGIENE_STALE_DAYS`, `PR_HYGIENE_FAILED_DAYS`, and `PR_HYGIENE_NOW_EPOCH` as non-negative integers before running selection logic.

## Consequences

- Autonomous PR selection remains deterministic, but is less error-prone to maintain because the autonomous predicate is defined once.
- Misconfigured environment variables produce an actionable error message instead of partial selection or runtime failures.
