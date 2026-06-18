output "service_urls" {
  description = "HomeBloc service endpoints."
  value       = module.homebloc.service_urls
}

output "remote_root" {
  description = "Remote directory containing the installed HomeBloc compose stack."
  value       = module.homebloc.remote_root
}

output "homebloc_root" {
  description = "Persistent host path for Home Assistant config data."
  value       = module.homebloc.homebloc_root
}
