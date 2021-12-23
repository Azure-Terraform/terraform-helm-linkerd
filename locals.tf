locals {
  # set certification expiration date for the number of hours specified
  cert_expiration_date = timeadd(time_static.cert_create_time.rfc3339, "${var.ca_cert_expiration_hours}h")

  linkerd = {
    cniEnabled       = var.cni_enabled
    disableHeartBeat = true
    identity = {
      issuer = {
        scheme    = "kubernetes.io/tls"
        crtExpiry = local.cert_expiration_date
      }
    }
    proxyInjector = {
      namespaceSelector = {
        matchExpressions = [
          { key = "linkerd.io/is-control-plane", operator = "DoesNotExist" },
          { key = "linkerd", operator = "In", values = ["enabled"] }
          ]
      }
    }
    # Must ignore outbound 443 for vault injector to work
    # proxyInit = { ignoreOutboundPorts = "4567,4568,443" }
  }

  components = {
    linkerd = ["proxyInjector", "profileValidator"]
    viz     = ["tap", "tapInjector"]
    jaeger  = ["webhook"]
  }

  extension_values = {
    viz = concat(var.ha_enabled ? [file("${path.module}/templates/viz-ha.yaml")] : [], [
      yamlencode({
      prometheusUrl = "prometheus-aks-app-doliv-dev.us-doliv-dev.azure.lnrsg.io"
      prometheus = { enabled = false }
      grafanaUrl = "grafana-aks-app-doliv-dev.us-doliv-dev.azure.lnrsg.io"
      grafana = { enabled = false }
    })])
  }
}
