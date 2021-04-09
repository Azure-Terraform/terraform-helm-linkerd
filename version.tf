# Configure terraform and providers
terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">=2.1.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">=3.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.0.3"
    }
  }
}
