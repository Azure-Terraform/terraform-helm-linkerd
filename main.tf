resource "time_static" "cert_create_time" {}

resource "helm_release" "crds"  {
  name       = "linkerd"
  chart      = "linkerd-crds"
  namespace  = var.chart_namespace
  repository = var.chart_repository
  version    = var.chart_version
  timeout    = var.chart_timeout
  atomic     = var.atomic
  create_namespace = true
}

module "issuer" {
  source = "./modules/issuer"

  namespace  = var.chart_namespace
  extensions = var.extensions

  trust_anchor_validity_hours = var.trust_anchor_validity_hours
  issuer_validity_hours       = var.issuer_validity_hours
  ca_cert_expiration_hours    = var.ca_cert_expiration_hours

  depends_on = [helm_release.crds]
}

resource "helm_release" "cni" {
  count = var.cni_enabled ? 1 : 0

  name       = "linkerd-cni"
  namespace  = "linkerd-cni"
  chart      = "linkerd2-cni"
  repository = var.chart_repository
  timeout    = var.chart_timeout
  atomic     = var.atomic
  create_namespace = true
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
    var.ha_enabled ? [file("${path.module}/templates/control-plane-ha.yaml")] : [],
    [yamlencode(local.linkerd), var.additional_yaml_config]
  )

  depends_on = [helm_release.cni, module.issuer]
}

resource "helm_release" "extension" {
  for_each = var.extensions

  name      = "linkerd-${each.key}"
  chart     = "linkerd-${each.key}"
  namespace = "linkerd-${each.key}"

  repository = var.chart_repository
  version    = var.chart_version
  timeout    = var.chart_timeout
  atomic     = var.atomic

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

  values = lookup(local.extension_values, each.key, [])

  depends_on = [helm_release.control_plane]
}

