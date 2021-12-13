resource "time_static" "cert_create_time" {}

module "issuer" {
  source = "./modules/issuer"

  namespace  = var.chart_namespace
  extensions = var.extensions
}

resource "helm_release" "linkerd" {
  name       = "linkerd"
  chart      = "linkerd2"
  namespace  = var.chart_namespace
  repository = var.chart_repository
  version    = var.chart_version
  timeout    = var.chart_timeout
  atomic     = true

  set_sensitive {
    name  = "identityTrustAnchorsPEM"
    value = module.issuer.cert_pem.root
  }

  values = [
    yamlencode(local.linkerd),
    var.additional_yaml_config
  ]

  depends_on = [module.issuer]
}

resource "helm_release" "extension" {
  for_each = var.extensions

  repository = var.chart_repository
  version    = var.chart_version
  timeout    = var.chart_timeout
  atomic     = true

  name      = format("linkerd-%s", each.key)
  chart     = format("linkerd-%s", each.key)
  namespace = format("linkerd-%s", each.key)

  values = [
    yamlencode(local.extensions[each.key])
  ]

  depends_on = [helm_release.linkerd]
}

