# Linkerd Installtion into Kubernetes

This repo contains Terraform code to install the linkerd service mesh into Kubernetes.  It creates the certificates required by linkerd and installs using a helm chart.

## Example
~~~~
module "service_mesh" {
  source = "https://github.com/Azure-Terraform/terraform-helm-linkerd"

  # required values
  chart_version               = "2.9.2"
  ca_cert_expiration_hours    = 8760  # 1 year
  trust_anchor_validity_hours = 17520 # 2 years
  issuer_validity_hours       = 8760  # 1 year (must be shorter than the trusted anchor)

  # optional value for linkerd config (in this case, override the default 'clockSkewAllowance' of 20s (for example purposes))
  additional_yaml_config = yamlencode({ "identity" : { "issuer" : { "clockSkewAllowance" : "30s" } } })
}
~~~~

## Quick start

1. Install [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli).
2. Confirm you are running required/pinned version of terraform

```
terraform version
```

3. Deploy the code:

```
terraform init
terraform plan -out config.plan
terraform apply config.plan
```

Notes:

```
```

<!--- BEGIN_TF_DOCS --->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.14.0 |
| helm | >= 2.1.0 |
| kubernetes | >= 1.13.3 |
| local | >= 2.0.0 |
| null | >= 3.0.0 |
| tls | >= 3.0.0 |

## Providers

| Name | Version |
|------|---------|
| helm | >= 2.1.0 |
| kubernetes | >= 1.13.3 |
| tls | >= 3.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| additional\_yaml\_config | used for additional customization of the linkerd helm chart values | `string` | `""` | no |
| ca\_cert\_expiration\_hours | Number of hours added to installation time to calculate trust anchor certification expiration date | `number` | `8760` | no |
| certificate\_controlplane\_duration | Number of hours for controlplane certification expiration | `string` | `"1440h"` | no |
| certificate\_controlplane\_renewbefore | Number of hours before the control plane certification expiration to request for certificate renewal | `string` | `"48h"` | no |
| certificate\_webhook\_duration | Number of hours for webhook certification expiration | `string` | `"1440h"` | no |
| certificate\_webhook\_renewbefore | Number of hours before the webhook certification expiration to request for certificate renewal | `string` | `"48h"` | no |
| chart\_repository | Helm chart repository | `string` | `"https://helm.linkerd.io/stable"` | no |
| chart\_version | Helm chart version | `string` | `"2.10.1"` | no |
| issuer\_validity\_hours | Number of hours for which the issuer certification is valid (must be shorter than the trust anchor) | `number` | `8760` | no |
| jaeger\_additional\_yaml\_config | used for additional customization of the linkerd-jaeger helm chart values | `string` | `""` | no |
| namespaces | Namespaces for linkerd and optional extensions | `set(string)` | <pre>[<br>  "linkerd",<br>  "linkerd-viz"<br>]</pre> | no |
| trust\_anchor\_validity\_hours | Number of hours for which the trust anchor certification is valid | `number` | `17520` | no |
| viz\_additional\_yaml\_config | used for additional customization of the linkerd-viz helm chart values | `string` | `""` | no |

## Outputs

No output.

<!--- END_TF_DOCS --->
