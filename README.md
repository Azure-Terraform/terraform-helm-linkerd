# Linkerd Installtion into Kubernetes

This repo contains Terraform code to install the linkerd service mesh into Kubernetes.  It creates the certificates required by linkerd and installs using helm charts  Cert-Manager in the cluster is required.

## Example
~~~~
module "service_mesh" {
  source = "https://github.com/Azure-Terraform/terraform-helm-linkerd"

  # required values
  chart_version               = "2.10.1"
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
<!--- END_TF_DOCS --->
