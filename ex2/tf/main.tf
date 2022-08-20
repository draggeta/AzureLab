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
      skip_shutdown_and_force_delete = false
    }
  }
}

provider "http" {}

data "http" "ip" {
  url = "https://api.ipify.org"

  # Optional request headers
  request_headers = {
    Accept = "text/plain"
  }
}
