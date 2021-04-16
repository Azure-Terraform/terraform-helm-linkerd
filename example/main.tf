terraform {
  required_version = ">= 0.14.8"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=2.51.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">=2.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=1.13.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "kubernetes" {
  host                   = module.kubernetes.host
  client_certificate     = base64decode(module.kubernetes.client_certificate)
  client_key             = base64decode(module.kubernetes.client_key)
  cluster_ca_certificate = base64decode(module.kubernetes.cluster_ca_certificate)
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = module.kubernetes.host
    client_certificate     = base64decode(module.kubernetes.client_certificate)
    client_key             = base64decode(module.kubernetes.client_key)
    cluster_ca_certificate = base64decode(module.kubernetes.cluster_ca_certificate)
  }
}

data "azurerm_subscription" "current" {
}

resource "random_string" "product" {
  length  = 12
  special = false
  upper   = false
}

module "subscription" {
  source = "git::git@github.com:Azure-Terraform/terraform-azurerm-subscription-data.git?ref=v1.0.0"
  subscription_id = data.azurerm_subscription.current.subscription_id
}

module "naming" {
  source = "git::git@github.com:LexisNexis-RBA/terraform-azurerm-naming.git?ref=v1.0.18"
}

module "metadata" {
  source = "git::git@github.com:Azure-Terraform/terraform-azurerm-metadata.git?ref=v1.1.0"

  naming_rules = module.naming.yaml

  market              = "us"
  project             = "https://github.com/openrba/terraform-kubernetes-linkerd"
  location            = "eastus2"
  environment         = "sandbox"
  product_name        = random_string.product.result
  product_group       = random_string.product.result
  business_unit       = "infra"
  subscription_id     = module.subscription.output.subscription_id
  subscription_type   = "dev"
  resource_group_type = "app"
}

module "resource_group" {
  source = "git::git@github.com:Azure-Terraform/terraform-azurerm-resource-group.git?ref=v1.0.0"

  location = module.metadata.location
  names    = module.metadata.names
  tags     = module.metadata.tags
}

module "kubernetes" {
  source = "git::git@github.com:Azure-Terraform/terraform-azurerm-kubernetes.git?ref=v1.6.0"

  kubernetes_version = "1.19.7"

  location            = module.metadata.location
  names               = module.metadata.names
  tags                = module.metadata.tags
  resource_group_name = module.resource_group.name

  default_node_pool_name                = "default"
  default_node_pool_vm_size             = "Standard_B2s"
  default_node_pool_enable_auto_scaling = true
  default_node_pool_node_min_count      = 1
  default_node_pool_node_max_count      = 3
  default_node_pool_availability_zones  = [1, 2, 3]
}

output "aks_login" {
  value = "az aks get-credentials --name ${module.kubernetes.name} --resource-group ${module.resource_group.name}"
}

module "service_mesh" {
  source = "../"

  # required values
  chart_version               = "2.10.1"
  ca_cert_expiration_hours    = 8760  # 1 year
  trust_anchor_validity_hours = 17520 # 2 years
  issuer_validity_hours       = 8760  # 1 year (must be shorter than the trusted anchor)

  # optional value for linkerd config (in this case, override the default 'clockSkewAllowance' of 20s (for example purposes))
  additional_yaml_config = yamlencode({ "identity" : { "issuer" : { "clockSkewAllowance" : "30s" } } })
}
