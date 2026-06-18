locals {
  compose_sha        = filesha256("${path.module}/docker-compose.yml")
  deploy_script_sha  = filesha256("${path.module}/scripts/deploy-homebloc.sh")
  ssh_private_key    = var.ssh_private_key_path != "" ? file(pathexpand(var.ssh_private_key_path)) : null
  upload_dir         = "/tmp/cloudbloc-homebloc"
  install_docker_env = var.install_docker ? "true" : "false"
  privileged_env     = var.privileged ? "true" : "false"
  homebloc_root      = coalesce(var.homebloc_root, "/var/lib/homebloc")
  service_host       = coalesce(var.service_host, var.host)

  config_fingerprint = sha256(jsonencode({
    host                   = var.host
    ssh_user               = var.ssh_user
    ssh_port               = var.ssh_port
    remote_root            = var.remote_root
    homebloc_root          = local.homebloc_root
    service_host           = local.service_host
    http_port              = var.http_port
    timezone               = var.timezone
    home_assistant_version = var.home_assistant_version
    privileged             = var.privileged
    install_docker         = var.install_docker
  }))
}

resource "terraform_data" "homebloc" {
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
    source      = "${path.module}/scripts/deploy-homebloc.sh"
    destination = "${local.upload_dir}/deploy-homebloc.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ${local.upload_dir}/deploy-homebloc.sh",
      join(" ", [
        "sudo",
        "env",
        "REMOTE_ROOT='${var.remote_root}'",
        "HOMEBLOC_ROOT='${local.homebloc_root}'",
        "HTTP_PORT='${var.http_port}'",
        "TZ='${var.timezone}'",
        "HOME_ASSISTANT_VERSION='${var.home_assistant_version}'",
        "HOME_ASSISTANT_PRIVILEGED='${local.privileged_env}'",
        "INSTALL_DOCKER='${local.install_docker_env}'",
        "${local.upload_dir}/deploy-homebloc.sh",
      ]),
    ]
  }
}
