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
  description = "Number of hours for which the issuer certification is valid (must be shorter than the trust anchor)"
  type        = number
  default     = 8760 # 1 year
}

variable "ca_cert_expiration_hours" {
  description = "Number of hours added to installation time to calculate trust anchor certification expiration date"
  type        = number
  default     = 8760 # 1 year
}

variable "namespaces" {
  description = "Namespaces for linkerd and optional extensions"
  type        = set(string)
  default     = ["linkerd", "linkerd-viz"]

  validation {
    condition = alltrue([
      for n in var.namespaces : contains(["linkerd", "linkerd-viz", "linkerd-jaeger"], n)
    ])
    error_message = "The namespaces list must contain 'linkerd' and, optionally, any or all of the following: ['linkerd-viz', 'linkerd-jaeger']."
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

variable "viz_additional_yaml_config" {
  description = "used for additional customization of the linkerd-viz helm chart values"
  type        = string
  default     = ""
}

variable "jaeger_additional_yaml_config" {
  description = "used for additional customization of the linkerd-jaeger helm chart values"
  type        = string
  default     = ""
}

variable "certificate_controlplane_duration" {
  description = "Number of hours for controlplane certification expiration"
  type        = string
  default     = "48h"
}

variable "certificate_controlplane_renewbefore" {
  description = "Number of hours before the control plane certification expiration to request for certificate renewal"
  type        = string
  default     = "25h"
}

variable "certificate_webhook_duration" {
  description = "Number of hours for webhook certification expiration"
  type        = string
  default     = "24h"
}

variable "certificate_webhook_renewbefore" {
  description = "Number of hours before the webhook certification expiration to request for certificate renewal"
  type        = string
  default     = "1h"
}
