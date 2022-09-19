terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }

    http = {
      source  = "hashicorp/http"
      version = ">= 2.2"
    }

    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }

    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = true
    }
  }
}

#  Get tenant identifier.
data "azurerm_client_config" "current" {}

provider "http" {}

data "http" "ip" {
  url = "https://api.ipify.org"

  # Optional request headers
  request_headers = {
    Accept = "text/plain"
  }
}

provider "random" {}

# random_id for DNS names
resource "random_id" "unique" {
  keepers = {
    az_sub_id = data.azurerm_client_config.current.subscription_id
  }

  byte_length = 8
}
