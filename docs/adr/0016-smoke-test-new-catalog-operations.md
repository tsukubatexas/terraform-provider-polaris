# ADR 0016: Smoke-test new catalog operations in the final static infra gate

Date: 2026-09-07

Status: Accepted

## Context

The provider's operation registry is generated from the latest Apache Polaris OpenAPI specs.
When a new Polaris release changes the generated operations (beyond the release tag), the final
real-Polaris Terraform smoke test must evolve so the new capability is exercised against a live
Polaris service.

Apache Polaris 1.7.0 adds catalog API operations that are not part of the management API base
path, including:

- `registerView` (`POST /v1/{prefix}/namespaces/{namespace}/register-view`)
- `signRequest` (`POST /v1/{prefix}/namespaces/{namespace}/tables/{table}/sign`)

These endpoints are in the Iceberg REST Catalog API surface. In this provider, management
operations are relative to `/api/management/v1` while catalog operations are relative to
`/api/catalog` and include their own `/v1` prefix.

The final gate must remain stable without requiring external object storage or special runtime
configuration.

## Decision

Update `examples/test-catalog` (used by `scripts/test_catalog.sh`) to:

- Configure a second aliased provider instance pointing at the catalog API base (`/api/catalog`).
- Create and destroy a dedicated namespace in the test catalog using catalog operations.
- Invoke the new `registerView` and `signRequest` operations via `polaris_rest_call`, asserting
  real runtime behavior (currently HTTP 400 for `registerView` request validation and HTTP 404
  for `signRequest` in the default container).

This ensures the new operation IDs are exercised against a real Polaris container and validates
that routing/authentication works for the catalog API, without relying on external storage or
remote signing configuration being enabled.

## Consequences

- The final static infra check grows with Polaris releases that add catalog operations.
- The smoke test validates catalog API connectivity in addition to management API lifecycle.
- The operations are exercised via request-validation behavior (expected 400) rather than a full
  happy-path flow, trading depth for stability and minimal dependencies.

## Findings

- For Polaris deployments used in CI, the OAuth token URL remains under `/api/catalog/v1/oauth/tokens`,
  while catalog operation paths from the OpenAPI specs are appended to the catalog API base
  `/api/catalog` (for example `/api/catalog/v1/{prefix}/namespaces/...`).

- Against the `apache/polaris:latest` service container used by CI as of 2026-09-07, `signRequest`
  returns an HTTP 404 with a `NotFoundException` payload ("Unable to find matching target resource method").
  The static infra gate treats this as the expected behavior until a Polaris release enables the endpoint.
