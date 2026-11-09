# ADR 0017: Polaris Requires Parent Namespace Before Creating Nested Namespaces

Date: 2026-11-09

Status: Accepted

## Context

The durable static infra smoke test (`scripts/test_catalog.sh` + `examples/test-catalog`) creates a catalog, a namespace, and a table against a real Polaris container in `POLARIS_INFRA_MODE=service`.

When using a multi-part Iceberg REST namespace (path parameter encoded as parts joined with the ASCII unit separator `\u001F`, for example `agentic\u001Fsmoke`), Apache Polaris returns:

- HTTP 404 `NoSuchNamespaceException` with a message like `Namespace does not exist: agentic`

This occurs when attempting to create the nested namespace directly, without first creating the parent namespace (`agentic`).

## Decision

Update `examples/test-catalog/main.tf` to create the parent namespace (single-part) first, and then create the nested namespace used for the table and operation probes.

## Consequences

- The service-mode lifecycle smoke test reflects real Polaris behavior and remains stable across apply/destroy.
- The provider continues to model Iceberg REST namespace encoding via `\u001F` without attempting to hide Polaris runtime constraints.
