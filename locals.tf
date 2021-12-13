locals {
  # set certification expiration date for the number of hours specified
  cert_expiration_date = timeadd(time_static.cert_create_time.rfc3339, "${var.ca_cert_expiration_hours}h")

  namespaces = concat(
    [var.chart_namespace],
    [for e in var.extensions : format("linkerd-%s", e)]
  )

  linkerd = {
    cniEnabled       = var.cni_enabled
    installNamespace = false
    disableHeartBeat = true
    identity = {
      issuer = {
        scheme    = "kubernetes.io/tls"
        crtExpiry = local.cert_expiration_date
      }
    }
    proxyInjector = {
      caBundle       = module.issuer.cert_pem.webhook
      externalSecret = true
    }
    profileValidator = {
      externalSecret = true
      caBundle       = module.issuer.cert_pem.webhook
    }
  }

  extensions = {
    viz = {
      installNamespace = false
      tap = {
        caBundle       = module.issuer.cert_pem.webhook
        externalSecret = true
      }
      tapInjector = {
        caBundle       = module.issuer.cert_pem.webhook
        externalSecret = true
      }
    }

    jaeger = {
      installNamespace = false
      webhook = {
        caBundle       = module.issuer.cert_pem.webhook
        externalSecret = true
      }
    }
  }
}
