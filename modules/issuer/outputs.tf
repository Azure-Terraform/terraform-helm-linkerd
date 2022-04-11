output "cert_pem" {
  value     = { for k in keys(local.certs) : k => tls_self_signed_cert.this[k].cert_pem }
  sensitive = true
}
