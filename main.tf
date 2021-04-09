locals {
  cert_expiration_date = timeadd(timestamp(), "${var.ca_cert_expiration_hours}h")
  namespace = toset([
    "linkerd",
    "linkerd-viz",
    "linkerd-jaeger"
  ])
}

resource "tls_private_key" "linkerd" {
  for_each    = toset(["trust_anchor", "webhook_anchor"])
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "linkerd_trust_anchor" {
  key_algorithm     = tls_private_key.linkerd["trust_anchor"].algorithm
  private_key_pem   = tls_private_key.linkerd["trust_anchor"].private_key_pem
  is_ca_certificate = true

  validity_period_hours = var.trust_anchor_validity_hours
  allowed_uses          = ["cert_signing", "crl_signing"]

  subject {
    common_name = "root.linkerd.cluster.local"
  }
}

resource "tls_self_signed_cert" "webhook_anchor" {
  key_algorithm     = tls_private_key.linkerd["webhook_anchor"].algorithm
  private_key_pem   = tls_private_key.linkerd["webhook_anchor"].private_key_pem
  is_ca_certificate = true

  validity_period_hours = var.trust_anchor_validity_hours
  allowed_uses          = ["cert_signing", "crl_signing"]

  subject {
    common_name = "webhook.linkerd.cluster.local"
  }
}

resource "kubernetes_namespace" "namespace" {
  for_each = local.namespace
  metadata {
    name = each.key
    annotations = {
      "linkerd.io/inject" = "enabled"
    }
  }
}

resource "kubernetes_secret" "webhook_trust_anchor" {
  for_each   = local.namespace
  depends_on = [kubernetes_namespace.namespace]
  type       = "kubernetes.io/tls"
  metadata {
    name      = "webhook-issuer-tls"
    namespace = each.key
  }

  data = {
    "tls.crt" : tls_self_signed_cert.webhook_anchor.cert_pem
    "tls.key" : tls_private_key.linkerd["webhook_anchor"].private_key_pem
  }
}

resource "kubernetes_secret" "linkerd_trust_anchor" {
  depends_on = [kubernetes_namespace.namespace]
  type       = "kubernetes.io/tls"
  metadata {
    name      = "linkerd-trust-anchor"
    namespace = "linkerd"
  }

  data = {
    "tls.crt" : tls_self_signed_cert.linkerd_trust_anchor.cert_pem
    "tls.key" : tls_private_key.linkerd["trust_anchor"].private_key_pem
  }
}

resource "helm_release" "issuer" {
  depends_on = [kubernetes_secret.linkerd_trust_anchor]
  name       = "linkerd-issuer"
  namespace  = "linkerd"
  chart      = "${path.module}/charts/linkerd-issuers"
  values = [
    yamlencode({
      certificate = {
        controlplane = {
          duration    = "${var.certificate_controlplane_duration}"
          renewbefore = "${var.certificate_controlplane_renewbefore}"
        }
        webhook = {
          duration    = "${var.certificate_webhook_duration}"
          renewbefore = "${var.certificate_webhook_renewbefore}"
        }
      }
    })
  ]
}

resource "helm_release" "linkerd" {
  depends_on = [helm_release.issuer]
  name       = "linkerd"
  namespace  = "linkerd"
  repository = var.chart_repository
  chart      = "linkerd2"
  version    = var.chart_version

  values = [
    yamlencode({
      installNamespace        = false
      disableHeartBeat        = true
      identityTrustAnchorsPEM = tls_self_signed_cert.linkerd_trust_anchor.cert_pem
      identity = {
        issuer = {
          scheme    = "kubernetes.io/tls"
          crtExpiry = local.cert_expiration_date
        }
      }
      proxyInjector = {
        caBundle       = tls_self_signed_cert.webhook_anchor.cert_pem
        externalSecret = true
      }
      profileValidator = {
        externalSecret = true
        caBundle       = tls_self_signed_cert.webhook_anchor.cert_pem
      }
    }),
    var.additional_yaml_config
  ]
}
resource "helm_release" "linkerd-viz" {
  depends_on       = [helm_release.linkerd]
  name             = "linkerd-viz"
  namespace        = "linkerd-viz"
  create_namespace = true
  repository       = var.chart_repository
  chart            = "linkerd-viz"
  version          = var.chart_version

  values = [
    yamlencode({
      installNamespace = false
      tap = {
        caBundle       = tls_self_signed_cert.webhook_anchor.cert_pem
        externalSecret = true
      }
      tapInjector = {
        externalSecret = true
        caBundle       = tls_self_signed_cert.webhook_anchor.cert_pem
      }
    }),
    var.additional_yaml_config
  ]
}

resource "helm_release" "linkerd-jaeger" {
  depends_on = [helm_release.linkerd-viz]
  name       = "linkerd-jaeger"
  repository = "https://helm.linkerd.io/edge"
  chart      = "linkerd-jaeger"
  version    = "21.3.4"

  values = [
    yamlencode({
      installNamespace = false
      webhook = {
        externalSecret = true
        caBundle       = tls_self_signed_cert.webhook_anchor.cert_pem
      }
    }),
    var.additional_yaml_config
  ]
}
