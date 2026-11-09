# Data Model: Despliegue en un Solo Proveedor — Railway o Azure (Fase 2)

**Spec**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)

Este documento extiende el [data-model.md de la Fase 1](../001-railway-deployment/data-model.md).
Las entidades **Previsualización de cambios** y **Secreto** no cambian y no se repiten aquí. Las
entidades **Entorno** y **Servicio** se extienden con campos nuevos (se listan solo los campos
nuevos o modificados); el resto de sus campos siguen siendo los de la Fase 1.

## Entidad: Entorno (`environment`) — campos nuevos

| Campo | Tipo | Obligatorio | Regla de validación |
|---|---|---|---|
| `provider` | enum | sí | uno de `railway`, `azure` (FR-001). Valor por omisión de `service.provider` y de `database.provider` para todos los servicios de este entorno, cuando esos campos no se declaran explícitamente (Principio II sigue permitiendo la excepción explícita por servicio) |

## Entidad: Servicio (`service`) — campos nuevos o modificados

| Campo | Tipo | Obligatorio | Regla de validación |
|---|---|---|---|
| `domain_type` | enum | no (nuevo default) | `public` o `private`; **por omisión `private`** para cualquier servicio de tipo API (FR-010). Las dos aplicaciones web (`maily-backoffice`, `maily-frontend`) siguen declarándolo explícitamente como `public` |
| `provider` | enum | no (nuevo default) | uno de `railway`, `azure`, `aws`; por omisión hereda `environment.provider` en vez de fijarse siempre en `railway` (cambia el default de la Fase 1, que no tenía un `environment.provider` del que heredar) |

**Regla nueva de validación cruzada** (FR-014): si `service.provider` (o `database.provider`) de
cualquier entrada de un entorno difiere de `environment.provider`, la validación MUST emitir una
advertencia explícita (no un bloqueo — a diferencia de FR-005/FR-002, aquí el requisito es advertir
y pedir confirmación, por lo que un bloque `check` de Terraform sí es la herramienta correcta, al
contrario de lo que ya se descartó en research.md de 001 §9 para el caso de bloqueo duro) listando
cada servicio que se desvía y su proveedor real.

## Entidad: Red de aislamiento (`network_domain`) — nueva

Representa el límite que decide qué servicios pueden alcanzar a cuáles dentro de un entorno. Un
`environment` tiene exactamente una instancia, implementada por el proveedor activo
(`railway` o `azure` — mismo tipo de interfaz común que `service`, ver
contracts/network-domain-interface.md).

| Campo | Tipo | Obligatorio | Regla de validación |
|---|---|---|---|
| `provider` | enum | sí | hereda `environment.provider` |
| `public_services` | list(string) | sí | nombres de los servicios con `domain_type = public` de este entorno; en Azure determinan qué App Service queda en `subred-web` (research.md §1-2) |
| `private_services` | list(string) | sí | nombres de los servicios con `domain_type = private`; en Azure determinan qué Container App queda en `subred-apis` |
| `isolation_guarantee` | enum (output, no configurable) | — | `"red"` cuando `provider = azure` (impuesto por NSG, research.md §2); `"credenciales"` cuando `provider = railway` (no hay mecanismo de red equivalente, research.md de 001 §4) |

**Invariante**: cuando `provider = azure`, la base de datos del entorno (ver abajo) MUST vivir en
una subred distinta de `public_services`, con un NSG que solo permita entrada desde la subred de
`private_services` (FR-005). Cuando `provider = railway`, no existe un invariante de red equivalente
que el sistema pueda verificar; la garantía la da exclusivamente a quién se le entregan las
credenciales (ver Entidad Servicio, `secret_refs`/`database_connection` de la Fase 1, FR-006).

## Entidad: Base de datos del entorno (`environment_database`) — generaliza `external_database` de la Fase 1

La Fase 1 solo conocía la base de datos externa de Azure. Esta fase introduce una segunda variante
detrás de la misma interfaz (contracts/database-module-interface.md); cuál de las dos aplica lo
decide `environment.provider`, nunca una elección independiente:

| Campo | Tipo | Obligatorio | Regla de validación |
|---|---|---|---|
| `provider` | enum | sí | `azure` → variante **externa** (idéntica a `external_database` de la Fase 1, sin cambios); `railway` → variante **nueva**, administrada |
| `kind` | enum (derivado, no configurable) | — | `"referenciada"` (Azure: nunca creada ni destruida, Principio II) o `"administrada"` (Railway: creada y administrada por este repositorio, FR-011) |
| `connection_secret_ref` | string | sí | igual que en la Fase 1: referencia (no valor) al secreto con host, puerto, usuario y contraseña |
| `database_name` | string | sí | igual que en la Fase 1: distinta por entorno |

**Invariantes**:
- Variante `"referenciada"` (Azure): mismo invariante de la Fase 1 — ningún módulo declara un
  `resource` de escritura sobre este recurso, solo `data source` (FR-013).
- Variante `"administrada"` (Railway): el `resource` que la crea MUST pertenecer únicamente al
  entorno que la declaró; ningún módulo de esta variante MUST leer, copiar ni referenciar el
  recurso ya existente en Azure (FR-012). Dos entornos distintos en Railway nunca comparten la misma
  base de datos administrada.

**Relaciones**: un `service` con `requires_database = true` (campo ya existente en la Fase 1) se
conecta siempre a la `environment_database` del mismo entorno, sin importar cuál de las dos
variantes sea.

## Servicios nuevos en `services.tfvars` (FR-008/FR-009)

Se añaden como entradas nuevas, con el mismo esquema de `service` ya definido (Fase 1 + los campos
nuevos de arriba); ninguna requiere un módulo distinto a los tres ya existentes
(`modules/service/{railway,azure,aws}`):

| `name` (convención Principio VII) | Nombre usado en la conversación de origen | `domain_type` | `requires_database` |
|---|---|---|---|
| `mailysoft-clinicas-api-<entorno>` | `maily-clinics-api` | `private` (default nuevo) | `true` |
| `mailysoft-agenda-api-<entorno>` | `maily-schedule-api` | `private` (default nuevo) | `true` |
| `mailysoft-publica-api-<entorno>` | `maily-public-api` | `private` (default nuevo) | `true` (solo lectura) |
| `mailysoft-web-<entorno>` | `maily-frontend` | `public` | `false` (consume APIs, no la base directamente) |

La entrada `mailysoft-web-<entorno>` ya existe en `services.tfvars` desde la Fase 1 con
`enabled = false` (su código "aún no existía"); esta fase solo cambia ese valor a `true` cuando el
equipo decida habilitarla (FR-009) — no es un servicio nuevo en el esquema, solo un cambio de valor.

## Esquema de configuración por entorno (resumen, extiende el de la Fase 1)

```text
environments/<entorno>/
├── environment.tfvars      # + campo `provider` (nuevo)
├── services.tfvars         # + 3 APIs nuevas; `mailysoft-web-<entorno>.enabled` pasa a `true` cuando se decida
└── database.tfvars         # mismo archivo; su `provider` ahora puede resolver a "railway"
```

Añadir cualquiera de las tres APIs nuevas, o habilitar el frontend, sigue siendo únicamente añadir o
modificar una entrada de `services.tfvars`, igual que exige la Fase 1 (Principio III) — ningún
módulo cambia por este motivo.
