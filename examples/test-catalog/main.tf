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
  # The management API lives under `/api/management/v1` but Iceberg REST catalog operations
  # in the generated registry use `/v1/...` paths that are served under `/api/catalog`.
  catalog_endpoint = replace(var.endpoint, "/api/management/v1", "/api/catalog")
  catalog_name     = "agentic_test"
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
    catalogName = local.catalog_name
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

# Smoke-test new operations introduced in newer Polaris releases.
#
# These calls are intentionally validation-failing (400/404) so the final gate exercises
# the operation registry wiring against a real Polaris runtime without requiring external
# object storage or view metadata materialization.
data "polaris_rest_call" "register_view_smoke" {
  provider     = polaris.catalog
  operation_id = "registerView"
  path_params = {
    prefix    = local.catalog_name
    namespace = "default"
  }
  body                  = "{}"
  expected_status_codes = [400, 404]

  depends_on = [polaris_rest_resource.test_catalog]
}

data "polaris_rest_call" "sign_request_smoke" {
  provider     = polaris.catalog
  operation_id = "signRequest"
  path_params = {
    prefix    = local.catalog_name
    namespace = "default"
    table     = "missing"
  }
  body                  = "{}"
  expected_status_codes = [400, 404]

  depends_on = [polaris_rest_resource.test_catalog]
}
