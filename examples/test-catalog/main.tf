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

variable "catalog_endpoint" {
  type        = string
  default     = ""
  description = "Optional Polaris catalog base endpoint (without the /v1 path segment). Example: https://polaris.example/api/catalog."
}

variable "realm" {
  type = string
}

variable "token" {
  type      = string
  sensitive = true
}

locals {
  management_endpoint = var.endpoint
  catalog_endpoint = var.catalog_endpoint != "" ? var.catalog_endpoint : replace(var.endpoint, "/api/management/v1", "/api/catalog")
}

provider "polaris" {
  alias    = "management"
  endpoint = local.management_endpoint
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
  provider = polaris.management

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

data "polaris_rest_call" "exercise_register_view" {
  provider   = polaris.catalog
  depends_on = [polaris_rest_resource.test_catalog]

  operation_id = "registerView"

  path_params = {
    prefix    = "agentic_test"
    namespace = "default"
  }

  # Intentionally invalid payload: ensures the route exists and is authenticated
  # without creating durable view state in the smoke test.
  body                  = jsonencode({})
  expected_status_codes = [400, 404]
}

data "polaris_rest_call" "exercise_sign_request" {
  provider   = polaris.catalog
  depends_on = [polaris_rest_resource.test_catalog]

  operation_id = "signRequest"

  path_params = {
    prefix    = "agentic_test"
    namespace = "default"
    table     = "agentic_table"
  }

  # Intentionally invalid payload: ensures the route exists and is authenticated
  # without requiring remote signing to be configured in the smoke test container.
  body                  = jsonencode({})
  expected_status_codes = [400, 404]
}
