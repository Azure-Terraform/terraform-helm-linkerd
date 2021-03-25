# ---------------------------------------------------------------------------------------------------------------------
# required variables used for deployment of linkerd in K8s
# ---------------------------------------------------------------------------------------------------------------------
variable "chart_repository" {
  description = "Helm chart repository"
  type        = string
  default     = "https://helm.linkerd.io/stable"
}

variable "chart_version" {
  description = "Helm chart version"
  type        = string
  default     = "2.10.0"
}

variable "trust_anchor_validity_hours" {
  description = "Number of hours for which the trust anchor certification is valid"
  type        = number
  default     = 17520 # 2 years
}

variable "issuer_validity_hours" {
  description = "Number of hours for which the issuer certification is valid (must be shorter than the truste anchor)"
  type        = number
  default     = 8760 # 1 year
}

variable "ca_cert_expiration_hours" {
  description = "Number of hours added to installation time to calculate trust anchor certification expiration date"
  type        = number
  default     = 8760 # 1 year
}

# ---------------------------------------------------------------------------------------------------------------------
# optional variable used for additional customization of the helm chart values
# ---------------------------------------------------------------------------------------------------------------------
variable "additional_yaml_config" {
  description = "used for additional customization of the helm chart values"
  type        = string
  default     = ""
}
