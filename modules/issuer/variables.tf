variable "namespace" {
  type        = string
  description = "Namespace to install linkerd."
  default     = "linkerd"
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

variable "certificate_controlplane_duration" {
  description = "Number of hours for controlplane certification expiration"
  type        = string
  default     = "1440h0m0s"
}

variable "certificate_controlplane_renewbefore" {
  description = "Number of hours before the control plane certification expiration to request for certificate renewal"
  type        = string
  default     = "48h0m0s"
}

variable "certificate_webhook_duration" {
  description = "Number of hours for webhook certification expiration"
  type        = string
  default     = "1440h0m0s"
}

variable "certificate_webhook_renewbefore" {
  description = "Number of hours before the webhook certification expiration to request for certificate renewal"
  type        = string
  default     = "48h0m0s"
}
