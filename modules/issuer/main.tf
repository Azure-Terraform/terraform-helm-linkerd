# create certificates for the trust anchor and issuer
resource "tls_private_key" "this" {
  for_each    = local.certs
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

# Control Plane TLS Credentials
resource "tls_self_signed_cert" "this" {
  for_each = local.certs

  key_algorithm     = tls_private_key.this[each.key].algorithm
  private_key_pem   = tls_private_key.this[each.key].private_key_pem
  is_ca_certificate = true

  validity_period_hours = var.trust_anchor_validity_hours

  allowed_uses = each.value.allowed_uses

  subject {
    common_name = "${each.key}.linkerd.cluster.local"
  }
}

# create secret used for the control plane credentials
resource "kubernetes_secret" "this" {
  for_each = local.issuers

  type = "kubernetes.io/tls"

  metadata {
    name      = each.value.secret_name
    namespace = each.value.namespace
  }

  data = {
    "tls.crt" : tls_self_signed_cert.this[each.value.cert_key].cert_pem
    "tls.key" : tls_private_key.this[each.value.cert_key].private_key_pem
  }
}

resource "helm_release" "issuer" {
  name      = "linkerd-issuer"
  namespace = "linkerd"
  chart     = "${path.module}/chart"
  timeout   = var.chart_timeout
  values    = [yamlencode(local.chart_values)]
  atomic    = true

  depends_on = [kubernetes_secret.this]
}
