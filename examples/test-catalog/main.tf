terraform {
  required_providers {
    polaris = {
      source  = "tsukubatexas/polaris"
      version = "0.0.1"
    }
  }
}

variable "endpoint" {
  type = string
}

variable "realm" {
  type = string
}

variable "token" {
  type      = string
  sensitive = true
}

locals {
  # Management API operations in the generated registry are relative to /api/management/v1, while
  # catalog API operations are relative to /api/catalog and include their own /v1 prefix.
  catalog_endpoint = replace(var.endpoint, "/api/management/v1", "/api/catalog")
  namespace_name   = "agentic_smoke"
  missing_table    = "agentic_missing"
}

provider "polaris" {
  endpoint = var.endpoint
  realm    = var.realm
  token    = var.token
}

provider "polaris" {
  alias    = "catalog"
  endpoint = local.catalog_endpoint
  realm    = var.realm
  token    = var.token
}

resource "polaris_rest_resource" "test_catalog" {
  create_operation_id = "createCatalog"
  read_operation_id   = "getCatalog"
  delete_operation_id = "deleteCatalog"

  path_params = {
    catalogName = "agentic_test"
  }

  body = jsonencode({
    catalog = {
      type = "INTERNAL"
      name = "agentic_test"
      properties = {
        "default-base-location" = "s3://agentic-test/"
      }
      storageConfigInfo = {
        storageType      = "S3"
        allowedLocations = ["s3://agentic-test/"]
      }
    }
  })

  id_attribute = "name"
}

resource "polaris_rest_resource" "test_namespace" {
  provider = polaris.catalog

  create_operation_id = "createNamespace"
  read_operation_id   = "loadNamespaceMetadata"
  delete_operation_id = "dropNamespace"

  path_params = {
    prefix    = polaris_rest_resource.test_catalog.id
    namespace = local.namespace_name
  }

  body = jsonencode({
    namespace = [local.namespace_name]
  })
}

data "polaris_rest_call" "register_view_smoke" {
  provider = polaris.catalog

  operation_id          = "registerView"
  expected_status_codes = [400]

  path_params = {
    prefix    = polaris_rest_resource.test_catalog.id
    namespace = local.namespace_name
  }

  # Intentionally invalid JSON to exercise request validation without needing external object storage.
  body       = "{"
  depends_on = [polaris_rest_resource.test_namespace]
}

data "polaris_rest_call" "sign_request_smoke" {
  provider = polaris.catalog

  operation_id          = "signRequest"
  # Polaris may advertise this operation in the OpenAPI-derived registry before it is enabled in the
  # default container runtime; the real-Polaris gate asserts the current behavior explicitly.
  expected_status_codes = [404]

  path_params = {
    prefix    = polaris_rest_resource.test_catalog.id
    namespace = local.namespace_name
    table     = local.missing_table
  }

  # Intentionally invalid JSON to exercise request validation regardless of remote signing configuration.
  body       = "{"
  depends_on = [polaris_rest_resource.test_namespace]
}
