resource "time_static" "cert_create_time" {
}

locals {
  # set certification expiration date for the number of hours specified
  cert_expiration_date = timeadd(time_static.cert_create_time.rfc3339, "${var.ca_cert_expiration_hours}h")
}

# create certificates for the trust anchor and issuer
#
resource "tls_private_key" "linkerd" {
  for_each    = toset(["trust_anchor", "issuer"])
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

# Control Plane TLS Credentials
resource "tls_self_signed_cert" "linkerd-trust-anchor" {
  key_algorithm     = tls_private_key.linkerd["trust_anchor"].algorithm
  private_key_pem   = tls_private_key.linkerd["trust_anchor"].private_key_pem
  is_ca_certificate = true

  validity_period_hours = var.trust_anchor_validity_hours

  allowed_uses = ["cert_signing", "crl_signing", "server_auth", "client_auth"]

  subject {
    common_name = "root.linkerd.cluster.local"
  }
}

# Webhook TLS Credentials
resource "tls_self_signed_cert" "linkerd-issuer" {
  key_algorithm     = tls_private_key.linkerd["issuer"].algorithm
  private_key_pem   = tls_private_key.linkerd["issuer"].private_key_pem
  is_ca_certificate = true

  validity_period_hours = var.issuer_validity_hours

  allowed_uses = ["cert_signing", "crl_signing"]

  subject {
    common_name = "webhook.linkerd.cluster.local"
  }
}

#
# END

# create namespaces for linkerd and any extensions (linkerd-viz or linkerd-jaeger)
resource "kubernetes_namespace" "namespace" {
  for_each = var.namespaces
  metadata {
    name        = each.key
    annotations = (each.key != "linkerd") ? { "linkerd.io/inject" = "enabled" } : {}
    labels      = (each.key != "linkerd") ? { "linkerd.io/extension" = trimprefix(each.key, "linkerd-") } : {}
  }
}

# create secret used for the control plane credentials
resource "kubernetes_secret" "linkerd-trust-anchor" {
  depends_on = [kubernetes_namespace.namespace]

  type = "kubernetes.io/tls"

  metadata {
    name      = "linkerd-trust-anchor"
    namespace = "linkerd"
  }

  data = {
    "tls.crt" : tls_self_signed_cert.linkerd-trust-anchor.cert_pem
    "tls.key" : tls_private_key.linkerd["trust_anchor"].private_key_pem
  }
}

# create secrets used for the webhook credentials
resource "kubernetes_secret" "linkerd-issuer" {
  depends_on = [kubernetes_namespace.namespace]

  type = "kubernetes.io/tls"

  for_each = var.namespaces
  metadata {
    name      = "webhook-issuer-tls"
    namespace = each.key
  }

  data = {
    "tls.crt" : tls_self_signed_cert.linkerd-issuer.cert_pem
    "tls.key" : tls_private_key.linkerd["issuer"].private_key_pem
  }
}

resource "helm_release" "issuer" {
  depends_on = [kubernetes_secret.linkerd-trust-anchor]
  name       = "linkerd-issuer"
  namespace  = "linkerd"
  chart      = "${path.module}/charts/linkerd-issuers"
  timeout    = var.linkerd_helm_install_timeout_secs
  values = [
    yamlencode({
      installLinkerdViz    = contains(var.namespaces, "linkerd-viz") ? true : false
      installLinkerdJaeger = contains(var.namespaces, "linkerd-jaeger") ? true : false
      certificate = {
        controlplane = {
          duration    = var.certificate_controlplane_duration
          renewbefore = var.certificate_controlplane_renewbefore
        }
        webhook = {
          duration    = var.certificate_webhook_duration
          renewbefore = var.certificate_webhook_renewbefore
        }
      }
    })
  ]
}

resource "helm_release" "linkerd" {
  depends_on = [kubernetes_namespace.namespace, helm_release.issuer]

  name       = "linkerd"
  chart      = "linkerd2"
  repository = var.chart_repository
  version    = var.chart_version
  namespace        = "linkerd"
  create_namespace = false
  timeout    = var.linkerd_helm_install_timeout_secs

  values = [
    yamlencode({
      installNamespace        = false
      disableHeartBeat        = true
      identityTrustAnchorsPEM = tls_self_signed_cert.linkerd-trust-anchor.cert_pem
      identity = {
        issuer = {
          scheme    = "kubernetes.io/tls"
          crtExpiry = local.cert_expiration_date
        }
      }
      proxyInjector = {
        caBundle       = tls_self_signed_cert.linkerd-issuer.cert_pem
        externalSecret = true
      }
      profileValidator = {
        externalSecret = true
        caBundle       = tls_self_signed_cert.linkerd-issuer.cert_pem
      }
    }),
    var.additional_yaml_config
  ]
}

resource "helm_release" "linkerd-viz" {
  depends_on = [helm_release.linkerd]

  count = contains(var.namespaces, "linkerd-viz") ? 1 : 0

  name       = "linkerd-viz"
  chart      = "linkerd-viz"
  repository = var.chart_repository
  version    = var.chart_version
  namespace        = "linkerd-viz"
  create_namespace = false
  timeout    = var.linkerd_helm_install_timeout_secs

  values = [
    yamlencode({
      installNamespace = false
      tap = {
        caBundle       = tls_self_signed_cert.linkerd-issuer.cert_pem
        externalSecret = true
      }
      tapInjector = {
        externalSecret = true
        caBundle       = tls_self_signed_cert.linkerd-issuer.cert_pem
      }
    }),
    var.viz_additional_yaml_config
  ]
}

resource "helm_release" "linkerd-jaeger" {
  depends_on = [helm_release.linkerd-viz]

  count = contains(var.namespaces, "linkerd-jaeger") ? 1 : 0

  name       = "linkerd-jaeger"
  chart      = "linkerd-jaeger"
  repository = var.chart_repository
  version    = var.chart_version
  namespace        = "linkerd-jaeger"
  create_namespace = false
  timeout    = var.linkerd_helm_install_timeout_secs

  values = [
    yamlencode({
      installNamespace = false
      webhook = {
        externalSecret = true
        caBundle       = tls_self_signed_cert.linkerd-issuer.cert_pem
      }
    }),
    var.jaeger_additional_yaml_config
  ]
}
