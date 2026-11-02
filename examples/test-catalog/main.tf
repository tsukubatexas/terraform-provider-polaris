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
  catalog_endpoint = replace(var.endpoint, "/api/management/v1", "/api/catalog")
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

data "polaris_rest_call" "register_view_smoke" {
  provider = polaris.catalog

  operation_id          = "registerView"
  expected_status_codes = [404]
  depends_on            = [polaris_rest_resource.test_catalog]

  path_params = {
    prefix    = polaris_rest_resource.test_catalog.id
    namespace = "missing_namespace"
  }

  body = jsonencode({
    name                = "smoke_view"
    "metadata-location" = "s3://agentic-test/smoke/views/smoke_view/metadata.json"
  })
}

data "polaris_rest_call" "sign_request_smoke" {
  provider = polaris.catalog

  operation_id          = "signRequest"
  expected_status_codes = [400, 404]
  depends_on            = [polaris_rest_resource.test_catalog]

  path_params = {
    prefix    = polaris_rest_resource.test_catalog.id
    namespace = "missing_namespace"
    table     = "missing_table"
  }

  body = jsonencode({
    region = "us-east-1"
    uri    = "s3://agentic-test/smoke/sign_request"
    method = "GET"
    headers = {
      host = ["s3.amazonaws.com"]
    }
  })
}
