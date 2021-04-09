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

variable "ca_cert_expiration_hours" {
  description = "Number of hours added to installation time to calculate trust anchor certification expiration date"
  type        = number
  default     = 8760 # 1 year
}

variable "certificate_controlplane_duration" {
  description = "Number of hours added to installation time to calculate trust anchor certification expiration date"
  type        = string
  default     = "48h"
}

variable "certificate_controlplane_renewbefore" {
  description = "Number of hours added to installation time to calculate trust anchor certification expiration date"
  type        = string
  default     = "25h"
}

variable "certificate_webhook_duration" {
  description = "Number of hours added to installation time to calculate trust anchor certification expiration date"
  type        = string
  default     = "24h"
}

variable "certificate_webhook_renewbefore" {
  description = "Number of hours added to installation time to calculate trust anchor certification expiration date"
  type        = string
  default     = "1h"
}

# ---------------------------------------------------------------------------------------------------------------------
# optional variable used for additional customization of the helm chart values
# ---------------------------------------------------------------------------------------------------------------------
variable "additional_yaml_config" {
  description = "used for additional customization of the helm chart values"
  type        = string
  default     = ""
}
