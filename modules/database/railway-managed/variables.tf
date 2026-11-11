variable "environment_name" {
  type        = string
  description = "Nombre del entorno (dev, staging o production); se usa para nombrar el servicio y el volumen de Railway."
}

variable "railway_project_id" {
  type        = string
  description = "Id del proyecto Railway 'mailysoft' (bootstrap/railway-project)."
}

variable "railway_environment_id" {
  type        = string
  description = "Id del Railway Environment (dev/staging/production) al que pertenece esta base de datos."
}

variable "database_name" {
  type        = string
  description = "Nombre de la base de datos logica dentro del servicio de Postgres (distinta por entorno, igual que en la variante azure-existing)."
  default     = "mailysoft"
}

variable "postgres_image" {
  type        = string
  description = "Imagen de Postgres con SSL que publica Railway (research.md §3): ghcr.io/railwayapp-templates/postgres-ssl, con un tag por version mayor de Postgres."
  default     = "ghcr.io/railwayapp-templates/postgres-ssl:17"
}

variable "volume_size_gb" {
  type        = number
  description = "Tamano del volumen persistente adjunto al servicio. SIN CONECTAR todavia (main.tf, 2026-11-10): no se confirmo si el bloque \"volume\" de railway_service permite fijar el tamano via Terraform; revisar contra la salida real del siguiente plan/apply."
  default     = 10
}

variable "region" {
  type        = string
  description = "Region de Railway (FR-017 de 001-railway-deployment). null = usar el default de Railway."
  default     = null
  nullable    = true
}
