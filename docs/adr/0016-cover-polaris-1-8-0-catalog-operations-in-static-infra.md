# ADR 0016: Cover Polaris 1.8.0 Catalog Operations in Static Infra

Date: 2026-10-19

Status: Accepted

## Context

Apache Polaris `apache-polaris-1.8.0` updates the generated OpenAPI operation registry with new catalog operations:

- `registerView` (`POST /v1/{prefix}/namespaces/{namespace}/register-view`)
- `signRequest` (`POST /v1/{prefix}/namespaces/{namespace}/tables/{table}/sign`)

The provider’s final static infra gate (`scripts/test_catalog.sh` + `examples/test-catalog`) is intended to be a durable “real Polaris” Terraform lifecycle smoke test. When new operations appear in the registry, this gate must evolve so that new release capabilities are exercised against real infrastructure (ADR 0007).

Polaris runs its management and catalog APIs under different base paths. The provider configuration exposes a single `endpoint`, so the static infra example needs separate provider configurations to talk to both bases.

## Decision

- Extend `examples/test-catalog` to configure two provider instances:
  - `polaris.management` using the management API base (for catalog lifecycle CRUD).
  - `polaris.catalog` using the catalog API base (for catalog API operation coverage).
- Add smoke coverage for `registerView` and `signRequest` using `polaris_rest_call` with intentionally invalid request bodies and explicit `expected_status_codes`.
  - This exercises routing, authentication, and request validation for the new operations without creating additional durable catalog objects that would complicate cleanup in the destroy phase.
- Update `scripts/test_catalog.sh` to pass a `catalog_endpoint` (base without `/v1`) into Terraform so the catalog provider can call `/v1/...` paths from the generated operation registry.

## Consequences

- The static infra gate continues to validate a real Terraform apply/destroy lifecycle while also touching newly added catalog operation endpoints.
- The gate remains stable across environments that do not configure object-store remote signing or view metadata storage, because the new operation calls are expected to fail with client errors rather than requiring full feature configuration.
- Future Polaris releases that add or change operations must continue to extend `examples/test-catalog` and/or `scripts/test_catalog.sh` rather than relying on one-off CI-only checks.

## Findings

- Polaris management and catalog APIs are served under different base paths; the smoke test uses separate provider endpoints to avoid constructing incorrect URLs like `.../api/management/v1/v1/...`.

