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
  default     = "2.10.1"
}

variable "chart_namespace" {
  type        = string
  description = "Namespace to install linkerd."
  default     = "linkerd"
}

variable "chart_timeout" {
  description = "The number of seconds to wait for the linkerd chart to be deployed. the default is 900 (15 minutes)"
  type        = string
  default     = "900"
}

variable "trust_anchor_validity_hours" {
  description = "Number of hours for which the trust anchor certification is valid"
  type        = number
  default     = 17520 # 2 years
}

variable "issuer_validity_hours" {
  description = "Number of hours for which the issuer certification is valid (must be shorter than the trust anchor)"
  type        = number
  default     = 8760 # 1 year
}

variable "ca_cert_expiration_hours" {
  description = "Number of hours added to installation time to calculate trust anchor certification expiration date"
  type        = number
  default     = 8760 # 1 year
}

variable "extensions" {
  description = "Linkerd extensions to install."
  type        = set(string)
  default     = ["viz"]

  validation {
    condition = alltrue(
      [for n in var.extensions : contains(["viz", "jaeger"], n)]
    )
    error_message = "'extensions' must contain any or all of the following: ['viz', 'jaeger']."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# optional variable used for additional customization of the helm chart values
# ---------------------------------------------------------------------------------------------------------------------
variable "additional_yaml_config" {
  description = "used for additional customization of the linkerd helm chart values"
  type        = string
  default     = ""
}

variable "certificate_controlplane_duration" {
  description = "Number of hours for controlplane certification expiration"
  type        = string
  default     = "1440h"
}

variable "certificate_controlplane_renewbefore" {
  description = "Number of hours before the control plane certification expiration to request for certificate renewal"
  type        = string
  default     = "48h"
}

variable "certificate_webhook_duration" {
  description = "Number of hours for webhook certification expiration"
  type        = string
  default     = "1440h"
}

variable "certificate_webhook_renewbefore" {
  description = "Number of hours before the webhook certification expiration to request for certificate renewal"
  type        = string
  default     = "48h"
}
