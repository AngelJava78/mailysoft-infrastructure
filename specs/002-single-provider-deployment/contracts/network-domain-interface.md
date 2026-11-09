# Contrato: Interfaz común del módulo "red de aislamiento" (`network-domain`)

**Spec**: [spec.md](../spec.md) | **Data model**: [data-model.md](../data-model.md)

Formaliza, para `modules/network-domain/*`, la misma clase de interfaz común por tipo de recurso
que ya exige el Principio III para `modules/service/*` (contracts/service-module-interface.md de la
Fase 1). La Fase 1 no necesitó documentar esta interfaz porque solo existía la implementación de
Railway; esta fase añade `azure` y, con ella, la necesidad de una interfaz estable para que elegir
proveedor de red no cambie cómo el resto del entorno lo consume.

## Entradas (`variables.tf`)

| Variable | Tipo | Obligatoria | Descripción |
|---|---|---|---|
| `environment_name` | `string` | sí | Nombre del entorno (`dev`, `staging`, `production`) |
| `public_service_names` | `list(string)` | sí | Nombres de los servicios con `domain_type = public` de este entorno (data-model.md) |
| `private_service_names` | `list(string)` | sí | Nombres de los servicios con `domain_type = private` |
| `database_requires_isolation` | `bool` | no (default `true`) | Si es `true`, el módulo MUST aplicar la regla "solo los servicios privados llegan a la base" por el mecanismo más fuerte disponible (ver salida `isolation_guarantee`) |
| `tags` | `object({ proyecto = string, servicio = string, entorno = string, propietario = string, gestionado_por = string })` | sí | Mismas 5 etiquetas obligatorias del Principio VII (ver research.md de 001 §5 para el caso Railway, sin tags nativas) |

## Salidas (`outputs.tf`)

| Output | Tipo | Descripción |
|---|---|---|
| `isolation_guarantee` | `string` | `"red"` si el proveedor puede rechazar, en la propia red, cualquier origen no autorizado hacia la base de datos; `"credenciales"` si la única garantía disponible es a quién se le entregan las credenciales de conexión (FR-007). Ningún valor distinto a estos dos es válido |
| `compute_network_refs` | `map(string)` | Por proveedor: en Azure, los ids de las subredes `subred-web`/`subred-apis` que `modules/service/azure` debe usar para su integración de VNet; en Railway, `{}` (no aplica — el servicio usa la red privada propia del Railway Environment, research.md de 001 §3-4) |

## Comportamiento por proveedor

| Proveedor | `isolation_guarantee` | Mecanismo |
|---|---|---|
| `railway` | `"credenciales"` | Sin cambios respecto a la Fase 1 (research.md de 001 §4): dominio público/privado por servicio; ningún control adicional entre servicios privados de un mismo Railway Environment |
| `azure` | `"red"` | VNet con `subred-web`, `subred-apis`, `subred-data`; `nsg-apis` permite entrada solo desde `subred-web` y desde sí misma; `nsg-data` permite entrada solo desde `subred-apis` (research.md §2) |

Ninguna implementación MUST declarar un valor de `isolation_guarantee` distinto de los dos listados
arriba; si un proveedor futuro (AWS, Fase 3) no puede ofrecer ninguno de los dos mecanismos
reconocidos, su módulo MUST fallar la validación de forma explícita, con el mismo patrón que
`modules/service/azure`/`aws` usaban en la Fase 1 para "proveedor no disponible" (FR-005 de la Fase
1), hasta que se investigue y documente cuál de los dos aplica.
