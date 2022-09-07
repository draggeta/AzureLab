variable "tags" {
  type        = object({ env = string })
  description = "Tags to assign to "
  default = {
    "env" = "test"
  }
}

variable "primary_location" {
  type        = string
  description = "Primary location to deploy resources in"
  default     = "West Europe"
}

variable "secondary_location" {
  type        = string
  description = "Secondary location to deploy resources in"
  default     = "North Europe"
}

variable "prefix" {
  type        = string
  description = "Resource name prefix"
  default     = "euw-tst"
}

variable "secondary_prefix" {
  type        = string
  description = "Resource name prefix"
  default     = "eun-tst"
}

variable "org" {
  type        = string
  description = "Name of the organization (lowercase)"
  default     = "lab"
}

variable "credentials" {
  type        = map(string)
  description = "Username and password for the VM"
  default = {
    username = "adminuser"
    password = "AzureLabs10IT!"
  }
}
