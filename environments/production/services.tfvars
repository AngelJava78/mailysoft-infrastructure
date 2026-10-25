# Entidad "Servicio" (data-model.md). Mismo patron que environments/dev/services.tfvars,
# adaptado al sufijo -production (Principio VII). Todo cambio aqui pasa por aprobacion
# manual obligatoria antes de aplicarse (FR-009).

services = [
  {
    name              = "mailysoft-usuarios-api-production"
    enabled           = true
    provider          = "railway"
    servicio_tag      = "usuarios-api"
    propietario_tag   = "equipo-plataforma"
    source_repo       = "github.com/mailysoft/mailysoft-usuarios-api"
    source_ref        = "main"
    domain_type       = "public"
    requires_database = true
  },
  {
    name              = "mailysoft-pacientes-api-production"
    enabled           = true
    provider          = "railway"
    servicio_tag      = "pacientes-api"
    propietario_tag   = "equipo-plataforma"
    source_repo       = "github.com/mailysoft/mailysoft-pacientes-api"
    source_ref        = "main"
    domain_type       = "public"
    requires_database = true
  },
  {
    name              = "mailysoft-sistema-api-production"
    enabled           = true
    provider          = "railway"
    servicio_tag      = "sistema-api"
    propietario_tag   = "equipo-plataforma"
    source_repo       = "github.com/mailysoft/mailysoft-sistema-api"
    source_ref        = "main"
    domain_type       = "private"
    requires_database = false
  },
  {
    name              = "mailysoft-backoffice-production"
    enabled           = true
    provider          = "railway"
    servicio_tag      = "backoffice"
    propietario_tag   = "equipo-plataforma"
    source_repo       = "github.com/mailysoft/mailysoft-backoffice"
    source_ref        = "main"
    domain_type       = "public"
    requires_database = false
  },
  {
    name              = "mailysoft-web-production"
    enabled           = false
    provider          = "railway"
    servicio_tag      = "web"
    propietario_tag   = "equipo-plataforma"
    source_repo       = ""
    domain_type       = "public"
    requires_database = false
  },
]
