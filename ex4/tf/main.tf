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

provider "http" {}

provider "random" {}

data "http" "ip" {
  url = "https://api.ipify.org"

  # Optional request headers
  request_headers = {
    Accept = "text/plain"
  }
}


# random_id for spoke B external load balancer
resource "random_id" "spoke_b" {
  keepers = {
    azi_id = 1
  }

  byte_length = 8
}
# random_id for traffic manager
resource "random_id" "tm" {
  keepers = {
    azi_id = 1
  }

  byte_length = 8
}
