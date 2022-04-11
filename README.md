<!-- BEGIN_TF_DOCS -->


## Example

```hcl
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
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_yaml_config"></a> [additional\_yaml\_config](#input\_additional\_yaml\_config) | used for additional customization of the linkerd helm chart values | `string` | `""` | no |
| <a name="input_atomic"></a> [atomic](#input\_atomic) | Whether the chart should be installed with the atomic flag | `bool` | `true` | no |
| <a name="input_ca_cert_expiration_hours"></a> [ca\_cert\_expiration\_hours](#input\_ca\_cert\_expiration\_hours) | Number of hours added to installation time to calculate trust anchor certification expiration date | `number` | `8760` | no |
| <a name="input_certificate_controlplane_duration"></a> [certificate\_controlplane\_duration](#input\_certificate\_controlplane\_duration) | Number of hours for controlplane certification expiration | `string` | `"1440h0m0s"` | no |
| <a name="input_certificate_controlplane_renewbefore"></a> [certificate\_controlplane\_renewbefore](#input\_certificate\_controlplane\_renewbefore) | Number of hours before the control plane certification expiration to request for certificate renewal | `string` | `"48h0m0s"` | no |
| <a name="input_certificate_webhook_duration"></a> [certificate\_webhook\_duration](#input\_certificate\_webhook\_duration) | Number of hours for webhook certification expiration | `string` | `"1440h0m0s"` | no |
| <a name="input_certificate_webhook_renewbefore"></a> [certificate\_webhook\_renewbefore](#input\_certificate\_webhook\_renewbefore) | Number of hours before the webhook certification expiration to request for certificate renewal | `string` | `"48h0m0s"` | no |
| <a name="input_chart_namespace"></a> [chart\_namespace](#input\_chart\_namespace) | Namespace to install linkerd. | `string` | `"linkerd"` | no |
| <a name="input_chart_repository"></a> [chart\_repository](#input\_chart\_repository) | Helm chart repository | `string` | `"https://helm.linkerd.io/stable"` | no |
| <a name="input_chart_timeout"></a> [chart\_timeout](#input\_chart\_timeout) | The number of seconds to wait for the linkerd chart to be deployed. the default is 900 (15 minutes) | `string` | `"900"` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Helm chart version | `string` | `"2.11.1"` | no |
| <a name="input_cni_enabled"></a> [cni\_enabled](#input\_cni\_enabled) | Whether to enable the cni plugin. | `bool` | `true` | no |
| <a name="input_extensions"></a> [extensions](#input\_extensions) | Linkerd extensions to install. | `set(string)` | <pre>[<br>  "viz"<br>]</pre> | no |
| <a name="input_ha_enabled"></a> [ha\_enabled](#input\_ha\_enabled) | Whether to enable high availability settings. | `bool` | `true` | no |
| <a name="input_issuer_validity_hours"></a> [issuer\_validity\_hours](#input\_issuer\_validity\_hours) | Number of hours for which the issuer certification is valid (must be shorter than the trust anchor) | `number` | `8760` | no |
| <a name="input_trust_anchor_validity_hours"></a> [trust\_anchor\_validity\_hours](#input\_trust\_anchor\_validity\_hours) | Number of hours for which the trust anchor certification is valid | `number` | `17520` | no |

## Outputs

No outputs.



## Quick start

1.Install [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli).\
2.Sign into your [Azure Account](https://docs.microsoft.com/en-us/cli/azure/authenticate-azure-cli?view=azure-cli-latest)

```bash
# Login with the Azure CLI/bash terminal/powershell by running
az login

# Verify access by running
az account show --output jsonc

# Confirm you are running required/pinned version of terraform
terraform version
```

### Deploy the code

```bash
cd examples/sandbox
terraform init
terraform plan -out sandbox-01.tfplan
terraform apply sandbox-01.tfplan
```

### Test the code

```bash
cd tests
go mod init 'tests'
go test -run TestSandboxExample -v -timeout 30m
```

Or Using Make

```bash
make test
```
<!-- END_TF_DOCS -->