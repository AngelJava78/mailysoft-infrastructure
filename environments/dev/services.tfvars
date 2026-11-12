# Entidad "Servicio" (data-model.md). Anadir una API nueva = anadir una entrada aqui; nunca
# requiere tocar modules/ (FR-012).

services = [
  {
    name              = "mailysoft-usuarios-api-dev"
    enabled           = true
    provider          = "railway"
    servicio_tag      = "usuarios-api"
    propietario_tag   = "equipo-plataforma"
    source_repo       = "github.com/Quint4n4/mailySoft-usuarios"
    source_ref        = "main"
    domain_type       = "public"
    requires_database = true
  },
  {
    name              = "mailysoft-pacientes-api-dev"
    enabled           = true
    provider          = "railway"
    servicio_tag      = "pacientes-api"
    propietario_tag   = "equipo-plataforma"
    source_repo       = "github.com/Quint4n4/mailySoft-pacientes"
    source_ref        = "main"
    domain_type       = "public"
    requires_database = true
  },
  {
    name              = "mailysoft-sistema-api-dev"
    enabled           = true
    provider          = "railway"
    servicio_tag      = "sistema-api"
    propietario_tag   = "equipo-plataforma"
    source_repo       = "github.com/AngelJava78/maily-system-api"
    source_ref        = "main"
    domain_type       = "private"
    requires_database = false
  },
  {
    name              = "mailysoft-backoffice-dev"
    enabled           = true
    provider          = "railway"
    servicio_tag      = "backoffice"
    propietario_tag   = "equipo-plataforma"
    source_repo       = "github.com/AngelJava78/maily-backoffice"
    source_ref        = "main"
    domain_type       = "public"
    requires_database = false
  },
  {
    # mailysoft-web ya existe como proyecto de codigo (maily-frontend): se habilita
    # (002-single-provider-deployment, FR-009; antes enabled = false, Fase 1).
    name              = "mailysoft-web-dev"
    enabled           = true
    provider          = "railway"
    servicio_tag      = "web"
    propietario_tag   = "equipo-plataforma"
    source_repo       = "github.com/Quint4n4/mailySoft-frontend"
    source_ref        = "main"
    domain_type       = "public"
    requires_database = false
  },
  {
    # 002-single-provider-deployment (FR-008): maily-clinics-api. domain_type se omite a
    # proposito para que tome el valor por omision "private" (FR-010).
    name              = "mailysoft-clinicas-api-dev"
    enabled           = true
    provider          = "railway"
    servicio_tag      = "clinicas-api"
    propietario_tag   = "equipo-plataforma"
    source_repo       = "github.com/Quint4n4/mailySoft-clinicas"
    source_ref        = "main"
    requires_database = true
  },
  {
    # 002-single-provider-deployment (FR-008): maily-schedule-api. Ya exige token (confirmado
    # por el usuario): su llamada a mailysoft-usuarios-api para confirmar permiso se trata
    # igual que la de clinicas-api, no como un gap pendiente.
    name              = "mailysoft-agenda-api-dev"
    enabled           = true
    provider          = "railway"
    servicio_tag      = "agenda-api"
    propietario_tag   = "equipo-plataforma"
    source_repo       = "github.com/Quint4n4/mailySoft-agenda"
    source_ref        = "main"
    requires_database = true
  },
  {
    # 002-single-provider-deployment (FR-008): maily-public-api. Privada (confirmado por el
    # usuario): "sin token" no significa "expuesta a internet" — ver spec.md.
    name              = "mailysoft-publica-api-dev"
    enabled           = true
    provider          = "railway"
    servicio_tag      = "publica-api"
    propietario_tag   = "equipo-plataforma"
    source_repo       = "github.com/AngelJava78/maily-public-api"
    source_ref        = "main"
    requires_database = true
  },
]
