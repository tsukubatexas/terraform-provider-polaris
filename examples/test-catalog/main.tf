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
  catalog_name        = "agentic_test"
  warehouse_location_base = "s3://agentic-test"
  warehouse_location  = "${local.warehouse_location_base}/"
  namespace_parts     = ["agentic", "smoke"]
  namespace_root_parts = [local.namespace_parts[0]]
  namespace_path      = join("\u001F", local.namespace_parts)
  namespace_root_path = join("\u001F", local.namespace_root_parts)
  namespace_location  = "${local.warehouse_location}${join("/", local.namespace_parts)}/"
  namespace_root_location = "${local.warehouse_location}${join("/", local.namespace_root_parts)}/"
  table_name          = "example"
  table_location      = "${local.namespace_location}${local.table_name}"
  polaris_base_url    = replace(var.endpoint, "/api/management/v1", "")
  catalog_api_endpoint = "${local.polaris_base_url}/api/catalog"
}

provider "polaris" {
  alias    = "management"
  endpoint = var.endpoint
  realm    = var.realm
  token    = var.token
}

provider "polaris" {
  alias    = "catalog"
  endpoint = local.catalog_api_endpoint
  realm    = var.realm
  token    = var.token
}

resource "polaris_rest_resource" "test_catalog" {
  provider = polaris.management

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
        "default-base-location" = local.warehouse_location
      }
      storageConfigInfo = {
        storageType      = "S3"
        allowedLocations = [local.warehouse_location]
      }
    }
  })

  id_attribute = "name"
}

resource "polaris_rest_resource" "namespace_root" {
  provider = polaris.catalog

  create_operation_id = "createNamespace"
  read_operation_id   = "loadNamespaceMetadata"
  delete_operation_id = "dropNamespace"

  path_params = {
    prefix    = polaris_rest_resource.test_catalog.id
    namespace = local.namespace_root_path
  }

  body = jsonencode({
    namespace = local.namespace_root_parts
    properties = {
      owner    = "terraform-provider-polaris"
      location = local.namespace_root_location
    }
  })

  depends_on = [
    polaris_rest_resource.test_catalog,
  ]
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
      owner    = "terraform-provider-polaris"
      location = local.namespace_location
    }
  })

  depends_on = [
    polaris_rest_resource.namespace_root,
  ]
}

data "polaris_rest_call" "create_table_probe" {
  provider = polaris.catalog

  operation_id          = "createTable"
  expected_status_codes = [400]
  path_params = {
    prefix    = polaris_rest_resource.test_catalog.id
    namespace = local.namespace_path
    table     = local.table_name
  }
  body = jsonencode({})

  depends_on = [
    polaris_rest_resource.namespace,
  ]
}

data "polaris_rest_call" "register_view_probe" {
  provider = polaris.catalog

  operation_id           = "registerView"
  expected_status_codes  = [400]
  path_params = {
    prefix    = polaris_rest_resource.test_catalog.id
    namespace = local.namespace_path
  }
  body = jsonencode({
    name = "probe_view"
  })

  depends_on = [
    polaris_rest_resource.namespace,
  ]
}

data "polaris_rest_call" "sign_request_probe" {
  provider = polaris.catalog

  operation_id          = "signRequest"
  # Some Polaris service-mode images do not route this endpoint yet (404), while
  # newer builds may route it but reject our intentionally-invalid body (400).
  expected_status_codes = [400, 404]
  path_params = {
    prefix    = polaris_rest_resource.test_catalog.id
    namespace = local.namespace_path
    table     = local.table_name
  }
  # Intentionally invalid to avoid invoking any object-store signing integration.
  body = jsonencode({})

  depends_on = [
    polaris_rest_resource.namespace,
  ]
}
