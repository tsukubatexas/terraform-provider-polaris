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
  catalog_endpoint = replace(var.endpoint, "/api/management/v1", "/api/catalog")
  namespace        = ["agentic_coverage"]
  namespace_path   = join("\u001F", local.namespace)
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

resource "polaris_rest_resource" "namespace" {
  provider = polaris.catalog

  create_operation_id = "createNamespace"
  read_operation_id   = "loadNamespaceMetadata"
  delete_operation_id = "dropNamespace"

  path_params = {
    prefix    = polaris_rest_resource.test_catalog.id
    namespace = local.namespace_path
  }

  body = jsonencode({
    namespace  = local.namespace
    properties = {}
  })
}

data "polaris_rest_call" "register_view_coverage" {
  provider = polaris.catalog

  operation_id = "registerView"

  path_params = {
    prefix    = polaris_rest_resource.test_catalog.id
    namespace = local.namespace_path
  }

  body                  = "{}"
  expected_status_codes = [400]

  depends_on = [polaris_rest_resource.namespace]
}
