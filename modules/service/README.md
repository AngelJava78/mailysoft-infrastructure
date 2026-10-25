# modules/service

Módulo fachada: interfaz común para desplegar un servicio de MailySoft en cualquier
proveedor soportado. Despacha a `./railway` (operativo), `./azure` o `./aws` (stubs que
fallan la validación con un mensaje explícito — FR-005) según `var.provider_name`. Contrato
completo en
[contracts/service-module-interface.md](../../specs/001-railway-deployment/contracts/service-module-interface.md).

## Entradas principales

Ver contracts/service-module-interface.md para la tabla completa. Resumen: `name`,
`enabled`, `provider_name` (`railway`/`azure`/`aws`), `railway_project_id`,
`railway_environment_id`, `source_repo`, `source_ref`, `domain_type`, `custom_domain`,
`env_vars`, `secret_refs`, `resources`, `database_connection`, `tags`.

> `provider_name` corresponde al campo `provider` de
> [data-model.md](../../specs/001-railway-deployment/data-model.md); se renombra en el
> código porque `provider` es una palabra reservada en Terraform.

## Salidas

`service_id`, `public_url`, `internal_address`, `provider_available`.

## Ejemplo de uso

```hcl
module "pacientes_api" {
  source = "../../modules/service"

  name                   = "mailysoft-pacientes-api-dev"
  enabled                = true
  provider_name          = "railway"
  railway_project_id     = var.railway_project_id
  railway_environment_id = var.railway_environment_id
  source_repo            = "github.com/mailysoft/mailysoft-pacientes-api"
  domain_type            = "public"
  database_connection = {
    host       = module.mailysoft_db.host
    port       = module.mailysoft_db.port
    secret_ref = module.mailysoft_db.connection_secret_value
  }
  tags = {
    proyecto       = "mailysoft"
    servicio       = "pacientes-api"
    entorno        = "dev"
    propietario    = "equipo-plataforma"
    gestionado_por = "terraform"
  }
}
```

## Añadir un proveedor nuevo (fase futura)

1. Crear `modules/service/<proveedor>/` implementando la misma interfaz de entradas/salidas.
2. Añadir un bloque `module "<proveedor>" { count = ... }` más en `main.tf`, siguiendo el
   mismo patrón que `railway`/`azure`/`aws`.
3. Ningún entorno existente necesita cambiar: solo el `.tfvars` del entorno que active ese
   proveedor (Principio III).
