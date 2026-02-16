terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0"
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

# Get current client configuration
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  
  tags = var.tags
}

# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = "asp-${var.app_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  os_type  = "Linux"
  sku_name = "S1"
  
  tags = var.tags
}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  
  sku_name = "standard"
  
  # Security settings
  soft_delete_retention_days = 7
  purge_protection_enabled   = false # Set to true in production
  
  # Network settings
  public_network_access_enabled = true # Restrict in production
  
  tags = var.tags
}

# Generate secure password
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# Store secret in Key Vault
resource "azurerm_key_vault_secret" "db_password" {
  name         = "DbPassword"
  value        = random_password.db_password.result
  key_vault_id = azurerm_key_vault.main.id
  
  depends_on = [azurerm_key_vault_access_policy.terraform]
}

# Key Vault Access Policy for Terraform
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id
  
  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore", "Purge"
  ]
}

# Web App
resource "azurerm_linux_web_app" "main" {
  name                = var.app_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id
  
  https_only = true
  
  site_config {
    always_on = true
    
    application_stack {
      dotnet_version = "8.0"
    }
    
    # Health check
    health_check_path = "/health"
  }
  
  app_settings = {
    "ASPNETCORE_ENVIRONMENT" = "Production"
    "KeyVaultUrl"           = azurerm_key_vault.main.vault_uri
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = var.tags
}

# Key Vault Access Policy for Web App
resource "azurerm_key_vault_access_policy" "webapp" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = azurerm_linux_web_app.main.identity[0].tenant_id
  object_id    = azurerm_linux_web_app.main.identity[0].principal_id
  
  secret_permissions = [
    "Get", "List"
  ]
}

# Staging Slot
resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.main.id
  
  https_only = true
  
  site_config {
    always_on = true
    
    application_stack {
      dotnet_version = "8.0"
    }
    
    health_check_path = "/health"
  }
  
  app_settings = {
    "ASPNETCORE_ENVIRONMENT" = "Staging"
    "KeyVaultUrl"           = azurerm_key_vault.main.vault_uri
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = var.tags
}

# Key Vault Access Policy for Staging Slot
resource "azurerm_key_vault_access_policy" "staging" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = azurerm_linux_web_app_slot.staging.identity[0].tenant_id
  object_id    = azurerm_linux_web_app_slot.staging.identity[0].principal_id
  
  secret_permissions = [
    "Get", "List"
  ]
}