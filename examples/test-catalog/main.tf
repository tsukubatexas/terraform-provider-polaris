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

variable "catalog_name" {
  type    = string
  default = "agentic_test"
}

variable "token" {
  type      = string
  sensitive = true
}

locals {
  catalog_endpoint = replace(var.endpoint, "/api/management/v1", "/api/catalog")
}

provider "polaris" {
  alias    = "management"
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
  provider = polaris.management

  create_operation_id = "createCatalog"
  read_operation_id   = "getCatalog"
  delete_operation_id = "deleteCatalog"

  path_params = {
    catalogName = var.catalog_name
  }

  body = jsonencode({
    catalog = {
      type = "INTERNAL"
      name = var.catalog_name
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

  operation_id = "registerView"
  expected_status_codes = [
    404,
  ]

  depends_on = [polaris_rest_resource.test_catalog]

  path_params = {
    prefix    = var.catalog_name
    namespace = "missing_namespace_for_smoke_test"
  }

  body = jsonencode({
    name              = "smoke_view"
    "metadata-location" = "s3://agentic-test/missing/view-metadata.json"
  })
}

data "polaris_rest_call" "sign_request_smoke" {
  provider = polaris.catalog

  operation_id = "signRequest"
  expected_status_codes = [
    404,
  ]

  depends_on = [polaris_rest_resource.test_catalog]

  path_params = {
    prefix    = var.catalog_name
    namespace = "missing_namespace_for_smoke_test"
    table     = "missing_table_for_smoke_test"
  }

  body = jsonencode({
    region = "us-east-1"
    uri    = "s3://agentic-test/missing/object"
    method = "GET"
    headers = {
      host = ["example.com"]
    }
  })
}
