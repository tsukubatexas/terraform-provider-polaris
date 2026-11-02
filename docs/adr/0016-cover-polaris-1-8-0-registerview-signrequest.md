# ADR 0016: Cover Polaris 1.8.0 `registerView` and `signRequest` Operations in Static Infra

Date: 2026-11-02

Status: Accepted

## Context

Apache Polaris `apache-polaris-1.8.0` adds new catalog operations to the generated operation registry:

- `registerView` (`POST /v1/{prefix}/namespaces/{namespace}/register-view`)
- `signRequest` (`POST /v1/{prefix}/namespaces/{namespace}/tables/{table}/sign`)

The repository enforces that when generated operations change, the durable “real Polaris” static
infra gate must grow with the surface area (see ADR 0007).

In the `POLARIS_INFRA_MODE=service` test environment we do not assume access to external object
storage, so these operations may not be able to complete successfully end-to-end (they require view
metadata locations and/or storage signing context).

## Decision

Extend `examples/test-catalog` to invoke the new `registerView` and `signRequest` endpoints via
`polaris_rest_call` using the catalog endpoint (`/api/catalog`) while keeping the existing
management lifecycle (`createCatalog`/`deleteCatalog`) intact.

The calls are configured to accept expected “not found / invalid request” status codes so Terraform
apply/destroy stays green while still proving:

- The provider can route catalog operations to the catalog endpoint.
- Auth headers and realm handling work against a real Polaris service.
- The new endpoints exist and respond deterministically.

## Consequences

- The final static infra gate exercises `registerView` and `signRequest` against real Polaris.
- This is a coverage-oriented smoke check, not a full validation of view registration or remote
  signing behavior.
- If future infra environments can provide durable object storage for tests, this coverage should be
  upgraded to validate successful responses instead of expected error codes.

## Findings

- `registerView` can be exercised with a valid request body while intentionally targeting a missing
  namespace and accepting HTTP 404.
- `signRequest` responses may vary between HTTP 400 and 404 depending on server-side validation
  order; the smoke check accepts both while still rejecting auth failures.

