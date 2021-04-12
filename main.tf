locals {
  # set certification expiration date for the number of hours specified
  cert_expiration_date = timeadd(timestamp(), "${var.ca_cert_expiration_hours}h")
}

# create certificates for the trust anchor and issuer
#
resource "tls_private_key" "linkerd" {
  for_each    = toset(["trust_anchor", "issuer"])
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "linkerd-trust-anchor" {
  key_algorithm     = tls_private_key.linkerd["trust_anchor"].algorithm
  private_key_pem   = tls_private_key.linkerd["trust_anchor"].private_key_pem
  is_ca_certificate = true

  validity_period_hours = var.trust_anchor_validity_hours
  early_renewal_hours   = var.trust_anchor_validity_hours - 24

  allowed_uses = ["cert_signing", "crl_signing", "server_auth", "client_auth"]

  dns_names = ["root.linkerd.cluster.local"]

  subject {
    common_name = "root.linkerd.cluster.local"
  }
}

resource "tls_self_signed_cert" "linkerd-issuer" {
  key_algorithm     = tls_private_key.linkerd["issuer"].algorithm
  private_key_pem   = tls_private_key.linkerd["issuer"].private_key_pem
  is_ca_certificate = true

  validity_period_hours = var.issuer_validity_hours
  early_renewal_hours   = var.issuer_validity_hours - 24

  allowed_uses = ["cert_signing", "crl_signing"]

  dns_names = ["webhook.linkerd.cluster.local"]

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
    name = each.key
    #   annotations = {
    #     "linkerd.io/inject" = "enabled"
    #   }
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

resource "helm_release" "linkerd" {
  name       = "linkerd"
  chart      = "linkerd2"
  repository = var.chart_repository
  version    = var.chart_version

  create_namespace = false

  values = [<<-EOF
    installNamespace: false
    disableHeartBeat: true
 
    identity:
      issuer:
        scheme: kubernetes.io/tls
        crtExpiry: local.cert_expiration_date
 
    proxyInjector:
      externalSecret: true
      caBundle: tls_self_signed_cert.linkerd-trust-anchor.cert_pem
 
    proxyValidator:
      externalSecret: true
      caBundle: tls_self_signed_cert.linkerd-trust-anchor.cert_pem
  EOF
    , var.additional_yaml_config
  ]
}

resource "helm_release" "linkerd-viz" {
  depends_on = [helm_release.linkerd]

  count = contains(var.namespaces, "linkerd-viz") ? 1 : 0

  name       = "linkerd-viz"
  chart      = "linkerd-viz"
  repository = var.chart_repository
  version    = var.chart_version

  create_namespace = false

  values = [<<-EOF
    installNamespace: false

    tap:
      externalSecret: true
      caBundle: tls_self_signed_cert.linkerd-issuer.cert_pem

    tapInjector:
      externalSecret: true
      caBundle: tls_self_signed_cert.linkerd-issuer.cert_pem
  EOF
    , var.viz_additional_yaml_config
  ]
}

resource "helm_release" "linkerd-jaeger" {
  depends_on = [helm_release.linkerd]

  count = contains(var.namespaces, "linkerd-jaeger") ? 1 : 0

  name       = "linkerd-jaeger"
  chart      = "linkerd-jaeger"
  repository = var.chart_repository
  version    = var.chart_version

  create_namespace = false

  values = [<<-EOF
    installNamespace: false

    webhook:
      externalSecret: true
      caBundle: tls_self_signed_cert.linkerd-issuer.cert_pem
  EOF
    , var.jaeger_additional_yaml_config
  ]
}
