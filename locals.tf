locals {
  issuer = {
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
  }

  linkerd = {
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
  }
}
