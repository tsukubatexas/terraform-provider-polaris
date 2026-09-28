# ADR 0016: Cover New Iceberg Catalog Operations in Static Infra

Date: 2026-09-28

Status: Accepted

## Context

The weekly regeneration of `internal/generated/operations_gen.go` against Apache Polaris `apache-polaris-1.8.0` added new Iceberg REST Catalog operations (notably `registerView` and `signRequest`).

The final static infra gate (`scripts/check_static_coverage.sh`) requires that when generated operations change, the durable real-Polaris smoke test (`scripts/test_catalog.sh` + `examples/test-catalog`) is updated to make an explicit coverage decision.

However, both new operations require infrastructure that is intentionally not part of the minimal service-mode container smoke test:

- `registerView` requires a view metadata file location that the Polaris service can read.
- `signRequest` is tied to remote signing configuration and an existing table/object-store request to sign.

## Decision

Extend `examples/test-catalog` to invoke the new generated operation IDs against a real Polaris container using the catalog endpoint provider alias, but assert stable negative responses that do not require external object storage or remote signing infrastructure.

- `registerView`: call against a known-missing namespace and expect `404`.
- `signRequest`: call against known-missing resources and expect `404`.

Also parameterize the catalog name (`catalog_name`) so `scripts/test_catalog.sh` and the Terraform config stay consistent when the test catalog name is overridden.

## Consequences

- The static infra gate now exercises the new generated operation IDs without requiring extra infrastructure beyond the service-mode Polaris container.
- The smoke test remains apply/destroy based and continues to validate provider/plugin lifecycle against real Polaris.
- If future Polaris images make these operations succeed in service mode (for example by bundling local storage or enabling remote signing), the smoke test can be upgraded from negative assertions to positive behavior.

## Findings

In the `apache/polaris:latest` container running Polaris `1.8.0`, both calls return `404` when the namespace/table are missing:

- `registerView` (`/v1/{prefix}/namespaces/{namespace}/register-view`) -> `404`
- `signRequest` (`/v1/{prefix}/namespaces/{namespace}/tables/{table}/sign`) -> `404`
