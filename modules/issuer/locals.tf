locals {

  namespaces = concat(
    [var.namespace],
    [for e in var.extensions : format("linkerd-%s", e)]
  )

  certs = {
    root = {
      allowed_uses = ["cert_signing", "crl_signing", "server_auth", "client_auth"]
    }
    webhook = {
      allowed_uses = ["cert_signing", "crl_signing"]
    }
  }

  issuers = merge(
    {
      linkerd-trust-anchor = {
        namespace   = var.namespace
        name        = "linkerd-trust-anchor"
        secret_name = "linkerd-trust-anchor" # checkov:skip=CKV_SECRET_6: Not a secret
        cert_key    = "root"
      }
    },
    {
      for n in local.namespaces : "${n}-webhook" => {
        namespace   = n
        name        = "webhook-issuer"
        secret_name = "webhook-issuer-tls" # checkov:skip=CKV_SECRET_6: Not a secret
        cert_key    = "webhook"
      }
    }
  )

  certificate_map = {
    linkerd = ["linkerd-proxy-injector", "linkerd-sp-validator"]
    linkerd-viz = ["tap", "tap-injector"]
    linkerd-jaeger = ["jaeger-injector"]
  }

  certificates = {
    for crt in flatten([
    for n in local.namespaces: [
      for c in local.certificate_map[n]: {
      namespace = n
      name = c
    }]]): "${crt.namespace}:${crt.name}" => crt }
}
