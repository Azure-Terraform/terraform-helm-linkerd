provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

module "service_mesh" {
  source = "../"

  ha_enabled  = true
  cni_enabled = true

  chart_timeout               = 2000
  ca_cert_expiration_hours    = 8760  # 1 year
  trust_anchor_validity_hours = 17520 # 2 years
  issuer_validity_hours       = 8760  # 1 year (must be shorter than the trusted anchor)

  # optional value for linkerd config (in this case, override the default 'clockSkewAllowance' of 20s (for example purposes))
  additional_yaml_config = yamlencode({ "identity" : { "issuer" : { "clockSkewAllowance" : "30s" } } })

  extensions = ["viz"]

  prometheus_url = "prometheus-aks-app-doliv-dev.us-doliv-dev.azure.lnrsg.io"
  grafana_url    = "grafana-aks-app-doliv-dev.us-doliv-dev.azure.lnrsg.io"
}
