locals {
  # Solo incluye las claves de los proyectos que var.environments_to_create realmente pidio
  # crear en este apply (ver main.tf) -- un entorno que aun no se crea simplemente no aparece.
  project_ids = merge(
    length(railway_project.dev) > 0 ? { dev = railway_project.dev[0].id } : {},
    length(railway_project.staging) > 0 ? { staging = railway_project.staging[0].id } : {},
    length(railway_project.production) > 0 ? { production = railway_project.production[0].id } : {},
  )

  environment_ids = merge(
    length(railway_project.dev) > 0 ? { dev = railway_project.dev[0].default_environment.id } : {},
    length(railway_project.staging) > 0 ? { staging = railway_project.staging[0].default_environment.id } : {},
    length(railway_project.production) > 0 ? { production = railway_project.production[0].default_environment.id } : {},
  )
}

output "project_ids" {
  value       = local.project_ids
  description = "Id de cada proyecto Railway ya creado (uno por entorno, ADR 0006); copiar al campo railway_project_id del environment.tfvars correspondiente. Solo incluye los entornos pedidos en var.environments_to_create."
}

output "environment_ids" {
  value       = local.environment_ids
  description = "Id del ambiente por defecto de cada proyecto ya creado; copiar al campo railway_environment_id del environment.tfvars correspondiente. Solo incluye los entornos pedidos en var.environments_to_create."
}
