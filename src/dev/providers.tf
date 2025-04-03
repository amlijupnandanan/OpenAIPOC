terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.66.0"
    }
  }
}
provider "azurerm" {
  features {}
   subscription_id = "cfa56b4d-9ab3-4006-a8dd-693d6517161f" #personal
   skip_provider_registration = true
}
