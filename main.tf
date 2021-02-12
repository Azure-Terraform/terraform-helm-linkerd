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

resource "tls_self_signed_cert" "linkerd-ca" {
  key_algorithm     = tls_private_key.linkerd["trust_anchor"].algorithm
  private_key_pem   = tls_private_key.linkerd["trust_anchor"].private_key_pem
  is_ca_certificate = true

  validity_period_hours = var.trust_anchor_validity_hours
  allowed_uses          = ["cert_signing", "crl_signing"]

  subject {
    common_name = "root.linkerd.cluster.local"
  }
}

resource "tls_cert_request" "linkerd-cert-request" {
  key_algorithm   = tls_private_key.linkerd["issuer"].algorithm
  private_key_pem = tls_private_key.linkerd["issuer"].private_key_pem

  subject {
    common_name = "identity.linkerd.cluster.local"
  }
}

resource "tls_locally_signed_cert" "linkerd-cert" {
  is_ca_certificate = true

  cert_request_pem = tls_cert_request.linkerd-cert-request.cert_request_pem

  ca_key_algorithm   = tls_private_key.linkerd["trust_anchor"].algorithm
  ca_private_key_pem = tls_private_key.linkerd["trust_anchor"].private_key_pem
  ca_cert_pem        = tls_self_signed_cert.linkerd-ca.cert_pem

  validity_period_hours = var.issuer_validity_hours
  allowed_uses          = ["cert_signing", "crl_signing"]
}
#
# END

resource "helm_release" "linkerd" {
  name             = "linkerd"
  chart            = "${var.chart_repository}/linkerd2-${var.chart_version}.tgz"
  version          = var.chart_version
  create_namespace = true

  set {
    name  = "global.identityTrustAnchorsPEM"
    value = tls_self_signed_cert.linkerd-ca.cert_pem
  }

  set {
    name  = "identity.issuer.tls.keyPEM"
    value = tls_private_key.linkerd["issuer"].private_key_pem
  }

  set {
    name  = "identity.issuer.tls.crtPEM"
    value = tls_locally_signed_cert.linkerd-cert.cert_pem
  }

  set {
    name  = "identity.issuer.crtExpiry"
    value = local.cert_expiration_date
  }

  values = [
    var.additional_yaml_config
  ]
}

