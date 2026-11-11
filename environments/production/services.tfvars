# Entidad "Servicio" (data-model.md). Mismo patron que environments/dev/services.tfvars,
# adaptado al sufijo -production (Principio VII). Todo cambio aqui pasa por aprobacion
# manual obligatoria antes de aplicarse (FR-009).

services = [
  {
    name              = "mailysoft-usuarios-api-production"
    enabled           = false
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
    enabled           = false
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
    enabled           = false
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
    enabled           = false
    provider          = "railway"
    servicio_tag      = "backoffice"
    propietario_tag   = "equipo-plataforma"
    source_repo       = "github.com/mailysoft/mailysoft-backoffice"
    source_ref        = "main"
    domain_type       = "public"
    requires_database = false
  },
  {
    # 002-single-provider-deployment (FR-009): habilitada, mismo motivo que en dev/staging.
    # Pasa por la misma aprobacion manual obligatoria de production que cualquier otro
    # cambio en este archivo (FR-009 de 001-railway-deployment).
    name              = "mailysoft-web-production"
    enabled           = false
    provider          = "railway"
    servicio_tag      = "web"
    propietario_tag   = "equipo-plataforma"
    source_repo       = "github.com/mailysoft/mailysoft-web"
    source_ref        = "main"
    domain_type       = "public"
    requires_database = false
  },
  {
    name              = "mailysoft-clinicas-api-production"
    enabled           = false
    provider          = "railway"
    servicio_tag      = "clinicas-api"
    propietario_tag   = "equipo-plataforma"
    source_repo       = "github.com/mailysoft/mailysoft-clinicas-api"
    source_ref        = "main"
    requires_database = true
  },
  {
    name              = "mailysoft-agenda-api-production"
    enabled           = false
    provider          = "railway"
    servicio_tag      = "agenda-api"
    propietario_tag   = "equipo-plataforma"
    source_repo       = "github.com/mailysoft/mailysoft-agenda-api"
    source_ref        = "main"
    requires_database = true
  },
  {
    name              = "mailysoft-publica-api-production"
    enabled           = false
    provider          = "railway"
    servicio_tag      = "publica-api"
    propietario_tag   = "equipo-plataforma"
    source_repo       = "github.com/mailysoft/mailysoft-publica-api"
    source_ref        = "main"
    requires_database = true
  },
]
