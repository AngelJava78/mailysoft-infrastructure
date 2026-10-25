# Entidad "Servicio" (data-model.md). Anadir una API nueva = anadir una entrada aqui; nunca
# requiere tocar modules/ (FR-012).

services = [
  {
    name            = "mailysoft-usuarios-api-dev"
    enabled         = true
    provider        = "railway"
    servicio_tag    = "usuarios-api"
    propietario_tag = "equipo-plataforma"
    source_repo     = "github.com/mailysoft/mailysoft-usuarios-api"
    source_ref      = "main"
    domain_type     = "public"
    requires_database = true
  },
  {
    name            = "mailysoft-pacientes-api-dev"
    enabled         = true
    provider        = "railway"
    servicio_tag    = "pacientes-api"
    propietario_tag = "equipo-plataforma"
    source_repo     = "github.com/mailysoft/mailysoft-pacientes-api"
    source_ref      = "main"
    domain_type     = "public"
    requires_database = true
  },
  {
    name            = "mailysoft-sistema-api-dev"
    enabled         = true
    provider        = "railway"
    servicio_tag    = "sistema-api"
    propietario_tag = "equipo-plataforma"
    source_repo     = "github.com/mailysoft/mailysoft-sistema-api"
    source_ref      = "main"
    domain_type     = "private"
    requires_database = false
  },
  {
    name            = "mailysoft-backoffice-dev"
    enabled         = true
    provider        = "railway"
    servicio_tag    = "backoffice"
    propietario_tag = "equipo-plataforma"
    source_repo     = "github.com/mailysoft/mailysoft-backoffice"
    source_ref      = "main"
    domain_type     = "public"
    requires_database = false
  },
  {
    # mailysoft-web aun no existe como proyecto de codigo (spec.md, Assumptions); queda
    # declarado y deshabilitado, listo para activarse cuando exista.
    name            = "mailysoft-web-dev"
    enabled         = false
    provider        = "railway"
    servicio_tag    = "web"
    propietario_tag = "equipo-plataforma"
    source_repo     = ""
    domain_type     = "public"
    requires_database = false
  },
]
