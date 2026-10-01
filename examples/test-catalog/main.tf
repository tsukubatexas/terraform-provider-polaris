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
  description = "Base Polaris Catalog API endpoint (without /v1), for example http://localhost:8181/api/catalog."
}

variable "realm" {
  type = string
}

variable "token" {
  type      = string
  sensitive = true
}

locals {
  catalog_name   = "agentic_test"
  namespace_name = "tf_smoke"
}

provider "polaris" {
  endpoint = var.endpoint
  realm    = var.realm
  token    = var.token
}

provider "polaris" {
  alias    = "catalog"
  endpoint = var.catalog_endpoint
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
    prefix    = local.catalog_name
    namespace = local.namespace_name
  }

  body = jsonencode({
    namespace = [local.namespace_name]
  })

  depends_on = [polaris_rest_resource.test_catalog]
}

data "polaris_rest_call" "register_view_smoke" {
  provider = polaris.catalog

  operation_id = "registerView"
  path_params = {
    prefix    = local.catalog_name
    namespace = local.namespace_name
  }

  body                  = jsonencode({ name = "smoke_view" })
  expected_status_codes = [400]

  depends_on = [polaris_rest_resource.test_namespace]
}

data "polaris_rest_call" "sign_request_smoke" {
  provider = polaris.catalog

  operation_id = "signRequest"
  path_params = {
    prefix    = local.catalog_name
    namespace = local.namespace_name
    table     = "missing"
  }

  body                  = jsonencode({})
  expected_status_codes = [400, 404]

  depends_on = [polaris_rest_resource.test_namespace]
}
