## Section to provide a random Azure region for the resource group
# This allows us to randomize the region for the resource group.
module "regions" {
  source  = "Azure/regions/azurerm"
  version = "0.8.0"
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region_index" {
  max = length(local.azure_regions) - 1
  min = 0
}
## End of section to provide a random Azure region for the resource group

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.2"
}

resource "azurerm_resource_group" "example" {
  location = local.azure_regions[random_integer.region_index.result]
  name     = module.naming.resource_group.name_unique
}

resource "azurerm_service_plan" "example" {
  location            = azurerm_resource_group.example.location
  name                = module.naming.app_service_plan.name_unique
  os_type             = "Linux"
  resource_group_name = azurerm_resource_group.example.name
  sku_name            = "FC1"
  tags = {
    app = "${module.naming.function_app.name_unique}-default"
  }
}

resource "azurerm_user_assigned_identity" "user" {
  location            = azurerm_resource_group.example.location
  name                = module.naming.user_assigned_identity.name_unique
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_storage_account" "example" {
  account_replication_type = "ZRS"
  account_tier             = "Standard"
  location                 = azurerm_resource_group.example.location
  name                     = module.naming.storage_account.name_unique
  resource_group_name      = azurerm_resource_group.example.name

  network_rules {
    default_action = "Allow"
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_storage_container" "example" {
  name               = "example-flexcontainer"
  storage_account_id = azurerm_storage_account.example.id
}

module "avm_res_web_site" {
  source = "../../"

  kind     = "functionapp"
  location = azurerm_resource_group.example.location
  name     = "${module.naming.function_app.name_unique}-flex"
  # Uses an existing app service plan
  os_type                  = azurerm_service_plan.example.os_type
  resource_group_name      = azurerm_resource_group.example.name
  service_plan_resource_id = azurerm_service_plan.example.id
  enable_telemetry         = var.enable_telemetry
  fc1_runtime_name         = "node"
  fc1_runtime_version      = "20"
  function_app_uses_fc1    = true
  instance_memory_in_mb    = 2048
  managed_identities = {
    # Identities can only be used with the Standard SKU
    system_assigned = true
    user_assigned_resource_ids = [
      azurerm_user_assigned_identity.user.id
    ]
  }
  maximum_instance_count = 100
  # Uses an existing storage account
  storage_account_access_key = azurerm_storage_account.example.primary_access_key
  # storage_authentication_type = "StorageAccountConnectionString"
  storage_authentication_type       = "UserAssignedIdentity"
  storage_container_endpoint        = azurerm_storage_container.example.id
  storage_container_type            = "blobContainer"
  storage_user_assigned_identity_id = azurerm_user_assigned_identity.user.id
  tags = {
    module  = "Azure/avm-res-web-site/azurerm"
    version = "0.17.2"
  }
}
