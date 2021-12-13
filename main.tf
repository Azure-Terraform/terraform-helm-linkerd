resource "time_static" "cert_create_time" {}

module "issuer" {
  source = "./modules/issuer"

  namespace  = var.chart_namespace
  extensions = var.extensions

  trust_anchor_validity_hours = var.trust_anchor_validity_hours
  issuer_validity_hours       = var.issuer_validity_hours
  ca_cert_expiration_hours    = var.ca_cert_expiration_hours
}

resource "helm_release" "cni" {
  count = var.cni_enabled ? 1 : 0

  name             = "linkerd-cni"
  namespace        = "linkerd-cni"
  chart            = "linkerd2-cni"
  create_namespace = true
  repository       = var.chart_repository
  atomic           = var.atomic
}

resource "helm_release" "linkerd" {
  name       = "linkerd"
  chart      = "linkerd2"
  namespace  = var.chart_namespace
  repository = var.chart_repository
  version    = var.chart_version
  timeout    = var.chart_timeout
  atomic     = var.atomic

  set_sensitive {
    name  = "identityTrustAnchorsPEM"
    value = module.issuer.cert_pem.root
  }

  values = concat(
    var.ha_enabled ? [data.http.ha_values.body] : [],
    [yamlencode(local.linkerd), var.additional_yaml_config]
  )

  depends_on = [helm_release.cni, module.issuer]
}

resource "helm_release" "extension" {
  for_each = var.extensions

  repository = var.chart_repository
  version    = var.chart_version
  timeout    = var.chart_timeout
  atomic     = var.atomic

  name      = format("linkerd-%s", each.key)
  chart     = format("linkerd-%s", each.key)
  namespace = format("linkerd-%s", each.key)

  values = [
    yamlencode(local.extensions[each.key])
  ]

  depends_on = [helm_release.linkerd]
}

