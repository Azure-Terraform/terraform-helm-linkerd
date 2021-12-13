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
