resource "time_static" "cert_create_time" {}

# create namespaces for linkerd and any extensions (linkerd-viz or linkerd-jaeger)
resource "kubernetes_namespace" "namespace" {
  for_each = toset(local.namespaces)
  metadata {
    name        = each.key
    annotations = { "linkerd.io/inject" = "disabled" }
    labels = {
      "linkerd.io/extension"                 = trimprefix(each.key, "linkerd-")
      "linkerd.io/is-control-plane"          = "true"
      "linkerd.io/control-plane-ns"          = each.key
      "config.linkerd.io/admission-webhooks" = "disabled"
    }
  }
}

resource "helm_release" "crds" {
  name             = "linkerd"
  chart            = "linkerd-crds"
  namespace        = var.chart_namespace
  repository       = "https://helm.linkerd.io/edge"
  version          = "1.3.0-edge"
  timeout          = var.chart_timeout
  atomic           = var.atomic
  create_namespace = false
  devel            = true

  depends_on = [kubernetes_namespace.namespace]
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
  depends_on = [kubernetes_namespace.namespace]

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
  name             = "linkerd-control-plane"
  chart            = "linkerd-control-plane"
  namespace        = var.chart_namespace
  create_namespace = false
  repository       = "https://helm.linkerd.io/edge"
  version          = "1.1.9-edge"
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

  depends_on = [helm_release.cni, module.issuer]
}

resource "helm_release" "extension" {
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

  depends_on = [helm_release.control_plane]
}

