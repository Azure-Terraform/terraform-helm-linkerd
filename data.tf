# data "http" "ha_values" {
#   count = var.ha_enabled ? 1 : 0

#   url = "https://raw.githubusercontent.com/linkerd/linkerd2/stable-${var.chart_version}/charts/linkerd2/values-ha.yaml"

#   request_headers = {
#     Accept = "text/x-yaml"
#   }
# }

# data "http" "viz_ha_values" {
#   count = var.ha_enabled ? 1 : 0

#   url = "https://raw.githubusercontent.com/linkerd/linkerd2/stable-${var.chart_version}/viz/charts/linkerd-viz/values-ha.yaml"

#   request_headers = {
#     Accept = "text/x-yaml"
#   }
# }
