# Data Model: Despliegue Automatizado de MailySoft en Railway (Fase 1)

**Spec**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)

Este documento traduce las entidades conceptuales del spec a la forma concreta de configuración
(variables de Terraform por entorno) que usarán los módulos. No es un modelo de base de datos de
aplicación: MailySoft como plataforma no almacena estos datos en una base de datos propia; viven
como archivos `.tfvars`/`.tf` versionados, consistentes con el Principio IV (Configuración sobre
Código).

## Entidad: Entorno (`environment`)

Un entorno es un directorio en `environments/<nombre>/` con su propio estado remoto (ver
research.md §6) y su propio archivo de configuración. No es un "objeto" Terraform en sí, sino el
ámbito que agrupa las demás entidades.

| Campo | Tipo | Obligatorio | Regla de validación |
|---|---|---|---|
| `name` | string | sí | uno de `dev`, `staging`, `production` (FR-003) |
| `railway_project_id` | string | sí (si hay servicios en Railway) | debe referenciar el proyecto Railway `mailysoft` existente |
| `railway_environment_id` | string | sí (si hay servicios en Railway) | id del Railway Environment nativo de este entorno (bootstrap/railway-project — research.md §3), distinto del `name` de arriba |
| `region_hint` | string | sí | región de referencia (más cercana a Azure) usada para resolver la región de cada servicio (FR-017) |

## Entidad: Servicio (`service`)

Representa una unidad desplegable (API, backoffice o frontend). Definido como un objeto dentro de
una colección `services` en la configuración de cada entorno.

| Campo | Tipo | Obligatorio | Regla de validación |
|---|---|---|---|
| `name` | string | sí | formato `mailysoft-<servicio>-<entorno>` (Principio VII); único dentro del entorno |
| `enabled` | bool | sí | si es `false`, el servicio no se despliega en ese entorno (FR-002) |
| `provider` | enum | sí | uno de `railway`, `azure`, `aws`; por defecto `railway` (FR-004). Si es `azure`/`aws` en esta fase, la validación de Terraform MUST fallar con un mensaje "proveedor no disponible aún" (FR-005) |
| `source_repo` | string | sí si `enabled=true` | URL o referencia del repositorio Python del microservicio (Principio I: solo se referencia, nunca se construye aquí) |
| `source_ref` | string | sí si `enabled=true` | rama o tag a desplegar |
| `domain_type` | enum | sí si `enabled=true` | `public` o `private` (ver research.md §4) |
| `custom_domain` | string | no | solo aplica si `domain_type=public`; vacío = usar dominio autogenerado |
| `env_vars` | map(string) | no | variables de entorno no sensibles del servicio |
| `secret_refs` | map(string) | no | nombres de secretos (no valores) que el pipeline debe inyectar desde GitHub Secrets/Azure Key Vault (FR-011) |
| `resources` | object | no | `{ cpu: string, memory_mb: number, replicas: number }`; valores por defecto razonables de Railway si se omite (Assumptions) |
| `requires_database` | bool | no (default `false`) | si es `true`, el módulo inyecta automáticamente la referencia a la base de datos externa (FR-007) |
| `servicio_tag` | string | sí | valor de la etiqueta obligatoria `servicio` (Principio VII) para este servicio, ej. `"usuarios-api"` |
| `propietario_tag` | string | sí | valor de la etiqueta obligatoria `propietario` (Principio VII) para este servicio |

**Relaciones**: un `service` pertenece a exactamente un `environment`; puede `requires_database` →
`external_database`.

**Transiciones de estado**: `enabled: false → true` (alta) y `enabled: true → false` (baja) son los
únicos dos cambios de ciclo de vida relevantes; ambos pasan por el flujo normal de
previsualización/aprobación (FR-008, FR-010), y una baja se marca como destructiva si implica
eliminar recursos ya desplegados.

## Entidad: Proveedor de destino (`provider`, valor del campo `service.provider` y de
`database.provider`)

No es una entidad con estado propio; es un enumerado validado en el punto de entrada de cada
módulo. Valores: `railway` (operativo en esta fase), `azure`, `aws` (reservados, resuelven a un
error de validación explícito en esta fase, ver FR-005).

## Entidad: Recurso de base de datos externo (`external_database`)

Representa `mailysoft-db`, la base de datos PostgreSQL ya existente en Azure. Se modela como
*data source*, nunca como recurso administrado (`resource`) en Terraform, para cumplir FR-006.

| Campo | Tipo | Obligatorio | Regla de validación |
|---|---|---|---|
| `provider` | enum | sí | en esta fase, fijo en `azure` (coherente con Assumptions del spec) |
| `resource_id` | string | sí | identificador del recurso Azure PostgreSQL existente, usado para resolver sus datos de conexión vía `data` source, nunca para crearlo |
| `connection_secret_ref` | string | sí | referencia (no valor) al secreto en Azure Key Vault / GitHub Secrets con host, puerto, usuario y contraseña |
| `database_name` | string | sí | base de datos lógica dentro del servidor. **Distinta por entorno** (`mailysoft_dev`, `mailysoft_staging`, `mailysoft` en production), para que un error en dev/staging nunca toque datos reales de pacientes, dado que los tres entornos comparten hoy el único servidor PostgreSQL existente en Azure |

**Invariantes**: ningún módulo de esta fase puede declarar un `resource "azurerm_postgresql..."`
de escritura sobre este recurso; solo `data "azurerm_postgresql_flexible_server" ...` (o
equivalente) y lectura del secreto de conexión.

## Entidad: Previsualización de cambios (`plan`)

No es una entidad de configuración sino el artefacto producido por `terraform plan` en cada
ejecución del pipeline. Atributos relevantes para las reglas de negocio del spec:

| Campo | Origen | Regla de negocio |
|---|---|---|
| `has_destructive_changes` | derivado de `terraform show -json <plan>` → acciones `delete`/`replace` | si es `true`, el pipeline MUST resaltarlo explícitamente y bloquear el `apply` hasta aprobación explícita (FR-010) |
| `environment` | parámetro del workflow | determina si se requiere aprobación manual obligatoria (`production`) o no (FR-009) |

## Entidad: Secreto (`secret`)

No se modela como variable de Terraform en texto plano. Se referencia siempre por nombre
(`secret_refs`, `connection_secret_ref`) y se resuelve en tiempo de ejecución del pipeline desde
GitHub Secrets/Environments o Azure Key Vault, marcándose `sensitive = true` en toda variable de
Terraform que lo contenga, para que nunca aparezca en el plan impreso ni en los logs (FR-011).

## Esquema de configuración por entorno (resumen)

```text
environments/<entorno>/
├── environment.tfvars      # campos de la entidad Entorno
├── services.tfvars         # lista de objetos "Servicio" (incluye su provider individual)
└── database.tfvars         # campos de la entidad "Recurso de base de datos externo"
```

Añadir un nuevo servicio (FR-012) = añadir un objeto a `services.tfvars` del entorno
correspondiente; nunca requiere tocar `modules/`.
