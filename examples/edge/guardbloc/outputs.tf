output "service_urls" {
  description = "GuardBloc service endpoints."
  value       = module.guardbloc.service_urls
}

output "remote_root" {
  description = "Remote directory containing the installed GuardBloc compose stack."
  value       = module.guardbloc.remote_root
}

output "guardbloc_root" {
  description = "Persistent host path for GuardBloc config/work data."
  value       = module.guardbloc.guardbloc_root
}
