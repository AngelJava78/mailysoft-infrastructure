# Contrato: Interfaz común del módulo "base de datos del entorno" (`database`)

**Spec**: [spec.md](../spec.md) | **Data model**: [data-model.md](../data-model.md)

Formaliza la interfaz común que `modules/database/azure-existing` (Fase 1, sin cambios) y
`modules/database/railway-managed` (nueva, esta fase) MUST implementar por igual, para que ningún
servicio consumidor necesite saber cuál de las dos está activa (Principio III).

## Entradas (`variables.tf`)

| Variable | Tipo | Obligatoria | Descripción |
|---|---|---|---|
| `environment_name` | `string` | sí | Nombre del entorno |
| `database_name` | `string` | sí | Base de datos lógica de este entorno (distinta por entorno, igual que en la Fase 1) |

`modules/database/azure-existing` añade además las variables ya definidas en la Fase 1
(`azure_resource_group_name`, `azure_db_server_name`, `connection_secret_name`, etc.: ahí sí
existe un secreto ya resuelto que referenciar, porque la base ya existe), sin cambios.
`railway-managed` añade las propias de su proveedor (proyecto/entorno de Railway, imagen,
tamaño de volumen), documentadas en su propio README (Principio VIII) — y **no** toma un
secreto como entrada: al crear la base por primera vez no hay ninguno que referenciar todavía,
así que genera su propia credencial (`random_password`) y la expone como
`connection_secret_value` (ver Salidas). Esta es una diferencia real entre variantes, no una
inconsistencia: lo único que el contrato común exige es que ambas entreguen la misma forma de
salida.

## Salidas (`outputs.tf`)

| Output | Tipo | Descripción |
|---|---|---|
| `host`, `port`, `database_name` | `string`/`number`/`string` | Mismos tres outputs ya expuestos por `azure-existing` en la Fase 1; `railway-managed` los replica con la misma forma |
| `connection_secret_value` | `string` (sensible) | La credencial de conexión — leída de Key Vault en `azure-existing`, generada con `random_password` en `railway-managed`. `environments/<entorno>/main.tf` combina estos tres/cuatro outputs en el objeto `{ host, port, secret_ref }` que ya consume `modules/service/*` (contracts/service-module-interface.md de la Fase 1) — ningún cambio en quien lo consume |
| `kind` | `string` | `"referenciada"` o `"administrada"` (data-model.md). Informativo: no cambia cómo se ensambla `database_connection`, solo documenta el origen para la previsualización y los runbooks |

## Invariantes por variante

| Variante | Invariante |
|---|---|
| `azure-existing` (`kind = "referenciada"`) | MUST modelarse únicamente con `data` sources; MUST NOT declarar ningún `resource` de escritura sobre el servidor o la base existente (Principio II, FR-013 de esta fase) |
| `railway-managed` (`kind = "administrada"`) | MUST declarar sus propios `resource` (servicio + volumen), aislados por entorno; MUST NOT leer, referenciar ni depender de ningún recurso de `azure-existing` (FR-012). Antes del primer `apply` real, MUST confirmarse contra el esquema real del provider (research.md §3) |

## Selección de variante

La variante activa la decide `environment.provider` (data-model.md), nunca una variable
independiente: `provider = azure` MUST resolver siempre a `azure-existing`; `provider = railway`
MUST resolver siempre a `railway-managed`. Esto evita el escenario de FR-014 (mezcla de
proveedores) específicamente para la base de datos, que por su sensibilidad (datos de pacientes,
Principio VI) no debe depender de una elección manual adicional separada de la del resto del
entorno.
