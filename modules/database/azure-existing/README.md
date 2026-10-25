# modules/database/azure-existing

Referencia de solo lectura a `mailysoft-db`, la base de datos PostgreSQL que ya existe en
Azure. Solo declara `data` sources; **nunca** un `resource` de escritura (FR-006). Ver
[data-model.md](../../../specs/001-railway-deployment/data-model.md) §"Recurso de base de
datos externo".

## Entradas

| Variable | Tipo | Obligatoria | Descripción |
|---|---|---|---|
| `resource_group_name` | `string` | sí | Resource group donde vive el servidor |
| `server_name` | `string` | sí | Nombre del servidor PostgreSQL existente |
| `server_type` | `string` | no (default `flexible`) | `flexible` o `single` |
| `database_name` | `string` | no (default `mailysoft`) | Nombre de la base de datos |
| `key_vault_id` | `string` | sí | Id del Key Vault con el secreto de conexión |
| `connection_secret_name` | `string` | no (default `mailysoft-db-connection`) | Nombre del secreto |

## Salidas

| Output | Sensible | Descripción |
|---|---|---|
| `host` | no | FQDN del servidor |
| `port` | no | Puerto (5432) |
| `database_name` | no | Nombre de la base de datos |
| `connection_secret_value` | **sí** | Credencial de conexión (nunca aparece en logs/plan) |

## Ejemplo de uso

```hcl
module "mailysoft_db" {
  source = "../../database/azure-existing"

  resource_group_name = "rg-mailysoft-shared"
  server_name         = "mailysoft-db"
  key_vault_id        = var.key_vault_id
}
```

## Invariante

Este módulo jamás debe ganar un `resource "azurerm_postgresql_flexible_server" ...` (o
equivalente) de escritura. La tarea T045 del plan de implementación audita este invariante
en todo el repositorio.
