# 0017 - Polaris Catalog Endpoint Excludes `/v1`

Date: 2026-10-01

## Context

Apache Polaris exposes multiple API surfaces.

- The Polaris **management** API is typically addressed at a base URL like `/api/management/v1` and operations in `spec/polaris-management-service.yml` use paths such as `/catalogs`.
- The Polaris **catalog** APIs (including Iceberg REST Catalog and OAuth token issuance) are addressed at a base URL like `/api/catalog`, while the OpenAPI operation paths include the `/v1/...` prefix (for example `/v1/{prefix}/namespaces` and `/v1/oauth/tokens`).

The static infra gate (`scripts/test_catalog.sh` + `examples/test-catalog`) started passing a catalog endpoint of `/api/catalog/v1`, which caused requests to be constructed as `/api/catalog/v1/v1/...` and return HTTP 404 (`Unable to find matching target resource method`).

## Decision

- Treat `POLARIS_ENDPOINT` / Terraform provider `endpoint` as the **management** base endpoint (for example `http://polaris:8181/api/management/v1`).
- Treat `POLARIS_CATALOG_ENDPOINT` / Terraform provider `catalog_endpoint` (as used by the `polaris` provider alias in `examples/test-catalog`) as the **catalog** base endpoint **without** `/v1` (for example `http://polaris:8181/api/catalog`).
- Update `scripts/test_catalog.sh` to:
  - Derive the default catalog endpoint from a management endpoint by replacing `/api/management[/v1]` with `/api/catalog`.
  - Request OAuth tokens from `${POLARIS_CATALOG_ENDPOINT}/v1/oauth/tokens` (matching the OpenAPI path).

## Consequences

- The static infra example and gate exercise both management and catalog APIs reliably across Polaris releases that keep the same base URL convention.
- Users configuring separate provider aliases should ensure the catalog provider uses an endpoint like `/api/catalog`, not `/api/catalog/v1`.

