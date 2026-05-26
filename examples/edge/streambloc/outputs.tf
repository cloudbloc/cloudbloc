output "service_urls" {
  description = "StreamBloc service URLs."
  value       = module.streambloc.service_urls
}

output "remote_root" {
  description = "Remote directory containing the installed StreamBloc compose stack."
  value       = module.streambloc.remote_root
}
