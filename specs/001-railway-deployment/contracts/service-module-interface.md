# Contrato: Interfaz común del módulo "servicio"

**Spec**: [spec.md](../spec.md) | **Data model**: [data-model.md](../data-model.md)

Este contrato define la interfaz estable que todo módulo de "servicio" (uno por proveedor) MUST
implementar, para que añadir un nuevo proveedor (Azure, AWS en fases futuras) no requiera cambiar
el módulo raíz ni los archivos de configuración por entorno (Principio III: interfaz común por
tipo de recurso detrás de una implementación por proveedor).

## Entradas (`variables.tf`)

| Variable | Tipo | Obligatoria | Descripción |
|---|---|---|---|
| `name` | `string` | sí | Nombre completo del servicio, formato `mailysoft-<servicio>-<entorno>` |
| `enabled` | `bool` | sí | Si es `false`, el módulo MUST no crear ningún recurso |
| `provider_name` | `string` | sí | `railway`, `azure` o `aws`. Corresponde al campo `provider` de data-model.md; se renombra en el código porque `provider` es una palabra reservada en Terraform |
| `railway_project_id` | `string \| null` | no (default `null`) | Id del proyecto Railway `mailysoft` (bootstrap/railway-project); requerido cuando `provider_name = railway` |
| `railway_environment_id` | `string \| null` | no (default `null`) | Id del Railway Environment del entorno; requerido cuando `provider_name = railway` |
| `source_repo` | `string` | no (default `""`) | Referencia al repositorio de código fuente del microservicio |
| `source_ref` | `string` | no (default `"main"`) | Rama o tag a desplegar |
| `region` | `string \| null` | no (default `null`) | Región resuelta por el entorno como la más cercana a la región de Azure de `mailysoft-db` (FR-017) |
| `domain_type` | `string` | no (default `"private"`) | `public` o `private` |
| `custom_domain` | `string` | no (default `""`) | Dominio personalizado; vacío = autogenerado |
| `env_vars` | `map(string)` | no (default `{}`) | Variables de entorno no sensibles |
| `secret_refs` | `map(string)` | no (default `{}`) | En esta capa ya llegan resueltos (valor real, marcado `sensitive`), nunca como nombres de secreto sin resolver (FR-011) |
| `resources` | `object({ cpu = optional(string), memory_mb = optional(number), replicas = optional(number, 1) })` | no | Tamaño/réplicas; valores por defecto del proveedor si se omite |
| `database_connection` | `object({ host = string, port = number, secret_ref = string }) \| null` | no (default `null`) | Dato de conexión externo ya resuelto (marcado `sensitive`), nunca un recurso administrado |
| `tags` | `object({ proyecto = string, servicio = string, entorno = string, propietario = string, gestionado_por = string })` | sí | Las 5 etiquetas obligatorias del Principio VII |

## Salidas (`outputs.tf`)

| Output | Tipo | Descripción |
|---|---|---|
| `service_id` | `string` | Identificador del recurso creado en el proveedor (o `null` si `enabled=false`) |
| `public_url` | `string \| null` | URL pública si `domain_type=public`; `null` en caso contrario |
| `internal_address` | `string \| null` | Dirección de red privada (ej. `<servicio>.railway.internal`) |
| `provider_available` | `bool` | `false` si el proveedor seleccionado aún no está operativo en esta fase (ver "Comportamiento de proveedor no disponible") |

## Comportamiento de proveedor no disponible (FR-005)

Los módulos de proveedores no operativos en esta fase (`azure`, `aws` para servicios de cómputo)
MUST implementar la misma interfaz de entradas/salidas, pero su lógica interna se reduce a una
validación que falla de forma explícita (un bloque `variable validation`; un `check` block NO
sirve aquí porque sus asserts solo emiten una advertencia, no bloquean el `apply` — ver
`modules/service/azure/variables.tf`) con un mensaje de la forma:

```text
El proveedor "azure" no está disponible aún para el servicio "<name>". Esta fase solo soporta
"railway". Ver specs/001-railway-deployment/spec.md (FR-005).
```

Este fallo MUST ocurrir en la etapa de validación/plan, antes de cualquier intento de `apply`,
nunca como un error parcial a mitad de una aplicación.

## Contrato de configuración por entorno

Ver [data-model.md](../data-model.md) para el esquema completo de `environment.tfvars`,
`services.tfvars` y `database.tfvars` que alimentan este módulo.
