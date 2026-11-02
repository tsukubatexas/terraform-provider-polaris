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
  namespace_parts   = ["agentic", "test"]
  namespace_path    = join("\u001F", local.namespace_parts)
  namespace_location = "s3://agentic-test/${join("/", local.namespace_parts)}"
  table_name        = "smoke_table"
  table_location    = "${local.namespace_location}/${local.table_name}"
  catalog_endpoint  = replace(var.endpoint, "/api/management/v1", "/api/catalog")
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
    namespace = local.namespace_parts
    properties = {
      owner    = "agentic"
      location = local.namespace_location
    }
  })

  depends_on = [
    polaris_rest_resource.test_catalog,
  ]
}

resource "polaris_rest_resource" "table" {
  provider = polaris.catalog

  create_operation_id = "createTable"
  read_operation_id   = "loadTable"
  delete_operation_id = "dropTable"

  path_params = {
    prefix    = polaris_rest_resource.test_catalog.id
    namespace = local.namespace_path
    table     = local.table_name
  }

  body = jsonencode({
    name     = local.table_name
    location = local.table_location
    schema = {
      type = "struct"
      fields = [
        {
          id       = 1
          name     = "id"
          type     = "string"
          required = true
        }
      ]
      "identifier-field-ids" = [1]
    }
    properties = {
      owner                  = "agentic"
      "write.format.default" = "parquet"
    }
  })

  expected_status_codes = [200, 201, 204]

  depends_on = [
    polaris_rest_resource.namespace,
  ]
}

data "polaris_rest_call" "tables" {
  provider = polaris.catalog

  operation_id = "listTables"

  path_params = {
    prefix    = polaris_rest_resource.test_catalog.id
    namespace = local.namespace_path
  }

  depends_on = [
    polaris_rest_resource.table,
  ]
}

output "tables_json" {
  value     = data.polaris_rest_call.tables.response_body
  sensitive = true
}
