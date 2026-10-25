output "project_id" {
  value       = railway_project.mailysoft.id
  description = "Id del proyecto Railway 'mailysoft'; copiar a railway_project_id en cada environments/<entorno>/environment.tfvars."
}

output "environment_ids" {
  value       = { for name, env in railway_environment.this : name => env.id }
  description = "Id de cada Railway Environment creado; copiar al campo railway_environment_id del entorno correspondiente."
}
