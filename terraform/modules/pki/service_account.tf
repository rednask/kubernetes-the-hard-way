resource "tls_private_key" "service_account" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "service_account" {
  key_algorithm   = "${tls_private_key.service_account.algorithm}"
  private_key_pem = "${tls_private_key.service_account.private_key_pem}"

  "subject" {
    common_name         = "service-accounts"
    organization        = "kubernetes"
    country             = "Poland"
    locality            = "Wroclaw"
    organizational_unit = "CA"
    province            = "Dolnoslaskie"
  }
}

resource "tls_locally_signed_cert" "service_account" {
  ca_cert_pem         = "${tls_self_signed_cert.ca.cert_pem}"
  ca_key_algorithm    = "${tls_private_key.ca.algorithm}"
  ca_private_key_pem  = "${tls_private_key.ca.private_key_pem}"

  cert_request_pem    = "${tls_cert_request.service_account.cert_request_pem}"

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "client_auth",
    "server_auth"
  ]

  validity_period_hours = 8760
}

resource "null_resource" "distribute_service_account_cert" {
  count = "${length(var.apiserver_node_names)}"

  connection {
    type         = "ssh"
    user         = "${var.ssh_user_controllers}"
    host         = "${element(var.apiserver_node_names, count.index)}"
    bastion_host = "${var.apiserver_public_ip}"
  }

  provisioner "file" {
    destination = "/home/zakal/service-account.pem"
    content     = "${tls_locally_signed_cert.service_account.cert_pem}"
  }

  provisioner "file" {
    destination = "/home/zakal/service-account-key.pem"
    content     = "${tls_private_key.service_account.private_key_pem}"
  }
}
