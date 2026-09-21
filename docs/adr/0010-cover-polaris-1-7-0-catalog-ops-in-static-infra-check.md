# ADR 0010: Cover Polaris 1.7.0 catalog operations in static infra check

Date: 2026-09-21

Status: Accepted

## Context

The weekly generation job updated the operation registry to `apache-polaris-1.7.0`. That release adds new Iceberg REST Catalog operations (notably `registerView` and `signRequest`) to `internal/generated/operations_gen.go`.

This repo intentionally treats changes to the generated operation registry as a signal that the "real Polaris" smoke test must grow as well (`scripts/check_static_coverage.sh`). Previously, `examples/test-catalog` only exercised management endpoints via the management base URL (`/api/management/v1`), so it did not cover catalog operations whose generated paths start with `/v1/...` and are served under the catalog base (`/api/catalog`).

## Decision

Extend `examples/test-catalog` to:

- Configure a second provider instance (alias) that targets the catalog base endpoint derived from the management endpoint.
- Execute the new `registerView` and `signRequest` operations using `polaris_rest_call` with `expected_status_codes` that accept validation-failure responses (400/404).

The smoke test intentionally sends `{}` bodies for these operations so it exercises:

- The generated operation registry lookup (`operation_id`).
- Provider URL construction to the catalog base (`/api/catalog/v1/...`).
- Authentication/realm headers against a live Polaris service.

…without depending on external object storage, view metadata materialization, or remote signing being fully configured.

## Consequences

- Static infra checks now cover the new `registerView` and `signRequest` capabilities introduced in `apache-polaris-1.7.0`.
- The final gate remains deterministic across CI environments because it does not require provisioning S3 credentials or producing real Iceberg view metadata.
- If future Polaris releases require materially different inputs/status codes for these endpoints, `examples/test-catalog` should be updated to keep the coverage meaningful and stable.

## Findings

- Polaris management endpoints are expected to be addressed via an endpoint like `.../api/management/v1`, while Iceberg REST Catalog endpoints are addressed via `.../api/catalog` plus the OpenAPI `/v1/...` paths from the generated operation registry.
