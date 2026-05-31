locals {
  compose_sha        = filesha256("${path.module}/docker-compose.yml")
  deploy_script_sha  = filesha256("${path.module}/scripts/deploy-guardbloc.sh")
  ssh_private_key    = var.ssh_private_key_path != "" ? file(pathexpand(var.ssh_private_key_path)) : null
  upload_dir         = "/tmp/cloudbloc-guardbloc"
  install_docker_env = var.install_docker ? "true" : "false"
  guardbloc_root     = coalesce(var.guardbloc_root, "/var/lib/guardbloc")

  config_fingerprint = sha256(jsonencode({
    host            = var.host
    ssh_user        = var.ssh_user
    ssh_port        = var.ssh_port
    remote_root     = var.remote_root
    guardbloc_root  = local.guardbloc_root
    service_bind_ip = var.service_bind_ip
    dns_port        = var.dns_port
    http_port       = var.http_port
    adguard_version = var.adguard_version
    install_docker  = var.install_docker
  }))
}

resource "terraform_data" "guardbloc" {
  triggers_replace = [
    local.compose_sha,
    local.deploy_script_sha,
    local.config_fingerprint,
  ]

  connection {
    type        = "ssh"
    host        = var.host
    user        = var.ssh_user
    port        = var.ssh_port
    private_key = local.ssh_private_key
    agent       = var.ssh_private_key_path == "" ? var.ssh_agent : false
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${local.upload_dir}",
    ]
  }

  provisioner "file" {
    source      = "${path.module}/docker-compose.yml"
    destination = "${local.upload_dir}/docker-compose.yml"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/deploy-guardbloc.sh"
    destination = "${local.upload_dir}/deploy-guardbloc.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ${local.upload_dir}/deploy-guardbloc.sh",
      join(" ", [
        "sudo",
        "env",
        "REMOTE_ROOT='${var.remote_root}'",
        "GUARDBLOC_ROOT='${local.guardbloc_root}'",
        "SERVICE_BIND_IP='${var.service_bind_ip}'",
        "DNS_PORT='${var.dns_port}'",
        "HTTP_PORT='${var.http_port}'",
        "ADGUARD_VERSION='${var.adguard_version}'",
        "INSTALL_DOCKER='${local.install_docker_env}'",
        "${local.upload_dir}/deploy-guardbloc.sh",
      ]),
    ]
  }
}
