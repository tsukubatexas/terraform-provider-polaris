# ADR 0016: Polaris 1.8.0 Static Infra Smoke Covers `registerView`

Date: 2026-10-12

Status: Accepted

## Context

The weekly spec refresh updated the generated operation registry to Apache Polaris release `apache-polaris-1.8.0`. The Iceberg REST Catalog OpenAPI spec added new catalog operations, including:

- `registerView` (`POST /v1/{prefix}/namespaces/{namespace}/register-view`)
- `signRequest` (`POST /v1/{prefix}/namespaces/{namespace}/tables/{table}/sign`)

The repository's final gate (`scripts/test_catalog.sh`) must evolve with new operations so green checks continue to represent real-Polaris compatibility.

## Decision

Extend `examples/test-catalog` to exercise the new `registerView` operation against a real Polaris service by:

- Creating a catalog via the management API.
- Creating a catalog namespace via the catalog API.
- Calling `registerView` via the catalog API with an intentionally invalid request body and asserting an HTTP `400` response.

This keeps the static smoke test durable (no external object-store setup required) while proving that the new route is present and performs request validation in the running Polaris container.

## Consequences

- When a new Polaris release adds operations, the static infra example gets an explicit, reviewable coverage update.
- The smoke test validates the existence of `registerView` without taking a dependency on view metadata files or object storage credentials.
- If Polaris later requires successful view registration to validate end-to-end behavior, update the static smoke test and add a follow-up ADR describing the additional runtime requirements.

