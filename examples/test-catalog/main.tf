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

provider "polaris" {
  endpoint = var.endpoint
  realm    = var.realm
  token    = var.token
}

locals {
  catalog_name      = "agentic_test"
  catalog_endpoint  = replace(var.endpoint, "/api/management/v1", "/api/catalog")
  namespace_name    = "smoke"
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
      name = local.catalog_name
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
    properties = {
      purpose = "static-infra-smoke-test"
    }
  })
}

data "polaris_rest_call" "register_view_smoke" {
  provider = polaris.catalog

  operation_id = "registerView"

  depends_on = [polaris_rest_resource.test_namespace]

  path_params = {
    prefix    = polaris_rest_resource.test_catalog.id
    namespace = local.namespace_name
  }

  # Polaris 1.8.0 added the /register-view endpoint. The real infra smoke test
  # triggers request validation to prove the route exists without requiring
  # object-store backed view metadata.
  body = jsonencode({})

  expected_status_codes = [400]
}
