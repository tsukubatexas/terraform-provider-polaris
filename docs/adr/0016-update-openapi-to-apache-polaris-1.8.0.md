# ADR 0016: Update OpenAPI inputs to apache-polaris-1.8.0

Date: 2026-10-01

Status: Accepted

## Context

The provider’s operation registry and documentation are generated from the latest Apache Polaris OpenAPI specs.

When a new Polaris release changes the generated operation registry, the repository requires the final “real Polaris”
static infra gate to evolve with it so the autonomous loop remains explainable and representative of current behavior.

The `apache-polaris-1.8.0` OpenAPI inputs add new Iceberg REST Catalog operations:

- `registerView` (`POST /v1/{prefix}/namespaces/{namespace}/register-view`)
- `signRequest` (`POST /v1/{prefix}/namespaces/{namespace}/tables/{table}/sign`)

## Decision

- Accept `apache-polaris-1.8.0` as the refreshed OpenAPI input used by `make generate`.
- Extend the durable real-Polaris Terraform smoke test (`examples/test-catalog`) to exercise the new catalog endpoints
  using a separate provider alias configured with the catalog API base URL.
- Treat the new operations as “API surface present” checks (expecting validation errors) rather than full success-path
  tests, to keep the final gate self-contained (no external object store dependency) while still ensuring the endpoints
  are wired and reachable in the running Polaris container.

## Consequences

- `scripts/test_catalog.sh` now passes both `endpoint` (management API) and `catalog_endpoint` (catalog API) into the
  Terraform test configuration.
- `examples/test-catalog` uses two provider instances:
  - default provider for management operations (catalog lifecycle)
  - `polaris.catalog` alias for catalog operations (namespace + new endpoint calls)
- The static gate exercises `registerView` and `signRequest` with intentionally-invalid request bodies and asserts
  Polaris returns `400` (and `404` for `signRequest` when the table is missing), keeping the test durable without
  requiring table/view metadata stored in an external bucket.

## Findings

- Polaris runs both management and catalog APIs under distinct base paths; the provider supports this via Terraform
  provider aliases with different `endpoint` values.
