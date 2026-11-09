# ADR 0016: Cover Polaris 1.8.0 Catalog Operation Additions in Static Infra

Date: 2026-11-09

Status: Accepted

## Context

The weekly generator update to Apache Polaris `apache-polaris-1.8.0` added new Iceberg REST catalog operations to the generated operation registry:

- `registerView` (`POST /v1/{prefix}/namespaces/{namespace}/register-view`)
- `signRequest` (`POST /v1/{prefix}/namespaces/{namespace}/tables/{table}/sign`)

The repository enforces `scripts/check_static_coverage.sh`: if generated operations change, the durable real-Polaris smoke test (`scripts/test_catalog.sh` + `examples/test-catalog`) must change as well so that new release surface is reviewed and intentionally handled.

The static infra test runs in `POLARIS_INFRA_MODE=service` against a real Polaris container. The test must remain stable without requiring external cloud credentials or object storage access.

## Decision

Extend `examples/test-catalog/main.tf` to:

- Create a catalog and namespaces through the Iceberg REST catalog API (provider alias pointing at `/api/catalog`).
- Probe `createTable` via `polaris_rest_call` expecting a validation error, rather than creating a real table.
- Add two explicit probes for the new `registerView` and `signRequest` operations using `polaris_rest_call`.

The probes intentionally send invalid request bodies (for example omitting required fields) and assert `expected_status_codes` that reflect real service-mode behavior. This exercises endpoint routing and request validation in a real Polaris runtime while avoiding external object-store access or remote-signing dependencies.

## Consequences

- The static infra gate now grows with Polaris 1.8.0 and provides a concrete, reviewable coverage story for the new operations.
- The smoke test does not attempt a fully successful `createTable`, `registerView`, or `signRequest` flow; those can trigger object-store integration (region/credentials) and/or require real metadata files and signing configuration, which are outside the scope of the minimal service-mode lifecycle check.
- Some Polaris service-mode images may return `404 NotFoundException` for `signRequest` (endpoint not routed yet); the probe accepts either `400` (validation) or `404` (not routed) so that the static infra gate remains stable while still flagging the behavior in a reviewable place.
- If future Polaris releases make these operations reliably testable end-to-end in service mode, the probes should be upgraded to assert successful (2xx) behavior instead of validation errors.
