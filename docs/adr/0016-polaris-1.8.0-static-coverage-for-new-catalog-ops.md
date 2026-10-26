# ADR 0016: Add Static Coverage for New Polaris 1.8.0 Catalog Operations

Date: 2026-10-26

Status: Accepted

## Context

The generator updates `internal/generated/operations_gen.go` whenever the upstream Polaris OpenAPI specs change.

Apache Polaris `apache-polaris-1.8.0` adds new Iceberg REST Catalog operations (`registerView` and `signRequest`).
Per ADR 0007, when generated operations change, the durable real-Polaris static infra smoke test must also change so
the release surface does not grow without an explicit coverage decision.

The final infra loop runs against a real Polaris container in service mode, without assuming external cloud
infrastructure (S3/GCS/Azure credentials, reachable buckets, etc.).

## Decision

Extend the durable static infra Terraform configuration in `examples/test-catalog` to:

- Create a namespace via the Catalog API, so Catalog-path operations have real preconditions.
- Exercise the newly-generated `registerView` operation via `polaris_rest_call` using an intentionally-invalid request
  body (`{}`) and assert an HTTP 400 response.

This verifies that the `registerView` endpoint exists and performs request validation, without requiring an object
store-backed metadata file to be available during the smoke test.

Additionally, pass the token into Terraform via `TF_VAR_token` in `scripts/test_catalog.sh` to avoid placing the bearer
token on the command line.

## Consequences

- The static infra gate grows with the generated operation registry.
- The smoke test now covers both Management API (catalog lifecycle) and Catalog API (namespace + registerView endpoint).
- The `registerView` call is expected to return an error code by design; the intent is endpoint coverage rather than
  creating a durable view state.

## Findings

- The Catalog API namespace delimiter used by the provider examples is the unit separator (`\u001F`) between namespace
  parts.
