# variable "cloudflare_api_token" {
#   type        = string
#   description = "Cloudflare API token"
# }

# variable "cloudflare_account_id" {
#   type        = string
#   description = "Cloudflare account ID"
# }

# variable "cloudflare_zone_id" {
#   type        = string
#   description = "Cloudflare zone ID for cloudbloc.io"
# }

# provider "cloudflare" {
#   api_token = var.cloudflare_api_token
# }

# resource "cloudflare_tunnel" "dropbloc" {
#   account_id = var.cloudflare_account_id
#   name       = "dropbloc"
#   config_src = "cloudflare"
# }

# resource "cloudflare_record" "dropbloc" {
#   zone_id = var.cloudflare_zone_id
#   name    = "dropbloc"
#   type    = "CNAME"
#   value   = "${cloudflare_tunnel.dropbloc.id}.cfargotunnel.com"
#   proxied = true
# }
