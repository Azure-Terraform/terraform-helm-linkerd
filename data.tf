data "http" "ha_values" {
  url = "https://raw.githubusercontent.com/linkerd/linkerd2/stable-${var.chart_version}/charts/linkerd2/values-ha.yaml"

  request_headers = {
    Accept = "text/x-yaml"
  }
}
