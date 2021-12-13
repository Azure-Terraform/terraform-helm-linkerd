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


# create namespaces for linkerd and any extensions (linkerd-viz or linkerd-jaeger)
resource "kubernetes_namespace" "namespace" {
  for_each = local.namespaces
  metadata {
    name        = each.key
    annotations = (each.key != var.namespace) ? { "linkerd.io/inject" = "enabled" } : {}
    labels      = (each.key != var.namespace) ? { "linkerd.io/extension" = trimprefix(each.key, "linkerd-") } : {}
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

  depends_on = [kubernetes_namespace.namespace]
}

resource "kubernetes_manifest" "issuer" {
  for_each = local.issuers

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Issuer"
    metadata = {
      name      = each.value.name
      namespace = each.value.namespace
    }
    spec = {
      ca = {
        secretName = each.value.secret_name # checkov:skip=CKV_SECRET_6: Irrelevent
      }
    }
  }
}

resource "kubernetes_manifest" "certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "linkerd-identity-issuer"
      namespace = var.namespace
    }
    spec = {
      commonName = "identity.linkerd.cluster.local"
      dnsNames   = ["identity.linkerd.cluster.local"]
      duration   = "48h0m0s"
      isCA       = true
      issuerRef = {
        kind = "Issuer"
        name = "linkerd-trust-anchor"
      }
      privateKey = {
        algorithm = "ECDSA"
      }
      renewBefore = "25h0m0s"
      secretName  = "linkerd-identity-issuer" # checkov:skip=CKV_SECRET_6: Irrelevent
      usages      = ["cert sign", "crl sign", "server auth", "client auth"]
    }
  }
}

resource "kubernetes_manifest" "webhook" {
  for_each = local.certificates

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = each.value.name
      namespace = each.value.namespace
    }
    spec = {
      commonName  = "${each.value.name}.linkerd.cluster.local"
      dnsNames    = ["${each.value.name}.linkerd.cluster.local"]
      duration    = var.certificate_webhook_duration
      renewBefore = var.certificate_webhook_renewbefore
      isCA        = false
      privateKey  = { algorithm = "ECDSA" }
      secretName  = "${each.value.name}-k8s-tls" # checkov:skip=CKV_SECRET_6: Irrelevent
      usages      = ["server auth"]
      issuerRef = {
        kind = "Issuer"
        name = "webhook-issuer"
      }
    }
  }
}
