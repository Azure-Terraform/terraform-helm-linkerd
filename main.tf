resource "time_static" "cert_create_time" {}

resource "kubernetes_namespace" "linkerd" {
  metadata {
    name        = var.chart_namespace
    annotations = { "linkerd.io/inject" = "disabled" }
    labels = {
      "linkerd.io/is-control-plane"          = "true"
      "config.linkerd.io/admission-webhooks" = "disabled"
      "linkerd.io/control-plane-ns"          = "linkerd"
    }
  }
}

resource "kubernetes_namespace" "linkerd-viz" {
  count = contains(var.extensions, "viz") ? 1 : 0

  metadata {
    name        = "linkerd-viz"
    annotations = { "linkerd.io/inject" = "enabled" }
    labels      = { "linkerd.io/extension" = "viz" }
  }
}

resource "kubernetes_namespace" "linkerd-jaeger" {
  count = contains(var.extensions, "jaeger") ? 1 : 0

  metadata {
    annotations = {
      "linkerd.io/inject"             = "enabled"
      "config.linkerd.io/proxy-await" = "enabled"
    }
    labels = { "linkerd.io/extension" = "jaeger" }
  }
}

resource "helm_release" "crds" {
  depends_on = [kubernetes_namespace.linkerd]

  name             = "linkerd"
  chart            = "linkerd-crds"
  namespace        = var.chart_namespace
  repository       = "https://helm.linkerd.io/edge"
  version          = "1.4.0"
  timeout          = var.chart_timeout
  atomic           = var.atomic
  create_namespace = false
  devel            = true
}

module "issuer" {
  depends_on = [helm_release.crds]

  source = "./modules/issuer"

  namespace  = var.chart_namespace
  extensions = var.extensions

  trust_anchor_validity_hours = var.trust_anchor_validity_hours
  issuer_validity_hours       = var.issuer_validity_hours
  ca_cert_expiration_hours    = var.ca_cert_expiration_hours
}

resource "helm_release" "cni" {
  depends_on = [kubernetes_namespace.linkerd]

  count = var.cni_enabled ? 1 : 0

  name             = "linkerd-cni"
  namespace        = "linkerd-cni"
  chart            = "linkerd2-cni"
  repository       = var.chart_repository
  timeout          = var.chart_timeout
  atomic           = var.atomic
  create_namespace = true
  devel            = true
}

resource "helm_release" "control_plane" {
  depends_on = [helm_release.cni, module.issuer]

  name             = "linkerd-control-plane"
  chart            = "linkerd-control-plane"
  namespace        = var.chart_namespace
  create_namespace = false
  repository       = "https://helm.linkerd.io/edge"
  version          = "1.9.3-edge"
  timeout          = var.chart_timeout
  atomic           = var.atomic
  devel            = true

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
}

resource "helm_release" "extension" {
  depends_on = [helm_release.control_plane]

  for_each = var.extensions

  name      = "linkerd-${each.key}"
  chart     = "linkerd-${each.key}"
  namespace = "linkerd-${each.key}"

  repository = var.chart_repository
  timeout    = var.chart_timeout
  atomic     = var.atomic
  devel      = true

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
}

