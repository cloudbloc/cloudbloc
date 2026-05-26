locals {
  compose_sha        = filesha256("${path.module}/docker-compose.yml")
  hwaccel_sha        = filesha256("${path.module}/docker-compose.hwaccel.yml")
  deploy_script_sha  = filesha256("${path.module}/scripts/deploy-streambloc.sh")
  ssh_private_key    = var.ssh_private_key_path != "" ? file(pathexpand(var.ssh_private_key_path)) : null
  upload_dir         = "/tmp/cloudbloc-streambloc"
  enable_hwaccel_env = var.enable_hwaccel ? "true" : "false"
  install_docker_env = var.install_docker ? "true" : "false"
  require_mount_env  = var.require_storage_mount ? "true" : "false"
  streambloc_root    = coalesce(var.streambloc_root, "${var.storage_root}/streambloc")
  media_root         = coalesce(var.media_root, "${var.storage_root}/streambloc-media")

  config_fingerprint = sha256(jsonencode({
    remote_root         = var.remote_root
    storage_root        = var.storage_root
    streambloc_root     = local.streambloc_root
    media_root          = local.media_root
    timezone            = var.timezone
    puid                = var.puid
    pgid                = var.pgid
    bind_ip             = var.bind_ip
    jellyfin_public_url = var.jellyfin_public_url
    enable_hwaccel      = var.enable_hwaccel
    install_docker      = var.install_docker
    require_mount       = var.require_storage_mount
    video_gid           = var.video_gid
    render_gid          = var.render_gid
  }))
}

resource "terraform_data" "streambloc" {
  triggers_replace = [
    local.compose_sha,
    local.hwaccel_sha,
    local.deploy_script_sha,
    local.config_fingerprint,
  ]

  connection {
    type        = "ssh"
    host        = var.tiny_host
    user        = var.tiny_user
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
    source      = "${path.module}/docker-compose.hwaccel.yml"
    destination = "${local.upload_dir}/docker-compose.hwaccel.yml"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/deploy-streambloc.sh"
    destination = "${local.upload_dir}/deploy-streambloc.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ${local.upload_dir}/deploy-streambloc.sh",
      join(" ", [
        "sudo",
        "env",
        "REMOTE_ROOT='${var.remote_root}'",
        "STORAGE_ROOT='${var.storage_root}'",
        "STREAMBLOC_ROOT='${local.streambloc_root}'",
        "MEDIA_ROOT='${local.media_root}'",
        "TZ='${var.timezone}'",
        "PUID='${var.puid}'",
        "PGID='${var.pgid}'",
        "BIND_IP='${var.bind_ip}'",
        "JELLYFIN_PUBLIC_URL='${var.jellyfin_public_url}'",
        "ENABLE_HWACCEL='${local.enable_hwaccel_env}'",
        "INSTALL_DOCKER='${local.install_docker_env}'",
        "REQUIRE_STORAGE_MOUNT='${local.require_mount_env}'",
        "VIDEO_GID='${var.video_gid}'",
        "RENDER_GID='${var.render_gid}'",
        "${local.upload_dir}/deploy-streambloc.sh",
      ]),
    ]
  }
}
