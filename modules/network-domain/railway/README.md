# modules/network-domain/railway

Gestiona el tipo de dominio de un servicio en Railway (research.md sección 4). La Private
Networking de Railway está activa por defecto para todo servicio de un mismo Railway
Environment (mesh WireGuard interno, `<servicio>.railway.internal`) y no requiere ningún
recurso de este módulo; `domain_type = "private"` por tanto no crea nada.

## ⚠️ Advertencia de verificación pendiente

Igual que `modules/service/railway`, los nombres de recurso `railway_service_domain` y
`railway_custom_domain` son el mejor esfuerzo basado en la terminología propia de Railway
("Generate Domain" / dominio personalizado vía CNAME+TXT) y no pudieron confirmarse contra
el registro del provider. Verificar antes del primer `terraform init` real.

## Entradas

| Variable | Tipo | Obligatoria | Descripción |
|---|---|---|---|
| `service_id` | `string` | sí | Id del `railway_service` |
| `environment_id` | `string` | sí | Id del Railway Environment |
| `domain_type` | `string` | sí | `public` o `private` |
| `custom_domain` | `string` | no | Dominio personalizado; vacío = autogenerado |

## Salidas

| Output | Descripción |
|---|---|
| `public_url` | URL pública resuelta, o `null` si `domain_type = private` |
