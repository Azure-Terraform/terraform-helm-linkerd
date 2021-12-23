resource "time_static" "cert_create_time" {}

module "issuer" {
  source = "./modules/issuer"

  namespace  = var.chart_namespace
  extensions = var.extensions

  trust_anchor_validity_hours = var.trust_anchor_validity_hours
  issuer_validity_hours       = var.issuer_validity_hours
  ca_cert_expiration_hours    = var.ca_cert_expiration_hours
}

resource "kubernetes_namespace" "cni" {
  count = var.cni_enabled ? 1 : 0
  metadata {
    name = "linkerd-cni"
  }
}

resource "helm_release" "cni" {
  count = var.cni_enabled ? 1 : 0

  name       = "linkerd-cni"
  namespace  = "linkerd-cni"
  chart      = "linkerd2-cni"
  repository = var.chart_repository
  atomic     = var.atomic

  set {
    name  = "installNamespace"
    value = "false"
  }

  depends_on = [kubernetes_namespace.cni]
}

resource "helm_release" "crds"  {
  name       = "linkerd"
  chart      = "linkerd-crds"
  namespace  = var.chart_namespace
  repository = var.chart_repository
  version    = var.chart_version
  timeout    = var.chart_timeout
  atomic     = var.atomic
}

resource "helm_release" "control_plane" {
  name       = "linkerd"
  chart      = "linkerd-control-plane"
  namespace  = var.chart_namespace
  repository = var.chart_repository
  version    = var.chart_version
  timeout    = var.chart_timeout
  atomic     = var.atomic

  set_sensitive {
    name  = "identityTrustAnchorsPEM"
    value = module.issuer.cert_pem.root
  }

  dynamic "set_sensitive" {
    for_each = toset(local.components.linkerd)
    content {
      name  = "${set_sensitive.key}.caBundle"
      value = module.issuer.cert_pem.webhook
    }
  }

  dynamic "set" {
    for_each = toset(local.components.linkerd)
    content {
      name  = "${set.key}.externalSecret"
      value = true
    }
  }

  values = concat(
    #var.ha_enabled ? [data.http.ha_values[0].body] : [],
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

  set {
    name  = "installNamespace"
    value = false
  }

  dynamic "set_sensitive" {
    for_each = toset(local.components[each.key])
    content {
      name  = "${set_sensitive.key}.caBundle"
      value = module.issuer.cert_pem.webhook
    }
  }

  dynamic "set" {
    for_each = toset(local.components[each.key])
    content {
      name  = "${set.key}.externalSecret"
      value = true
    }
  }

  #values = var.ha_enabled && each.key == "viz" ? [data.http.viz_ha_values[0].body] : []

  depends_on = [helm_release.linkerd]
}

