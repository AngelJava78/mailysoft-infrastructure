# ADR 0006: un proyecto de Railway por entorno, no Environments nativos dentro de un único proyecto

**Estado**: Aceptado
**Fecha**: 2026-11-11
**Contexto**: [specs/001-railway-deployment](../../specs/001-railway-deployment/) (research.md sección 3)
**Corrige en parte a**: `specs/001-railway-deployment/research.md` sección 3

## Contexto

`research.md` de `001-railway-deployment` (sección 3) decidió un único proyecto de Railway
(`mailysoft`) con tres **Railway Environments** nativos (`dev`, `staging`, `production`),
rechazando explícitamente la alternativa de "un proyecto de Railway distinto por entorno" por
considerar que "no aporta aislamiento adicional frente a usar Environments nativos, que ya
están diseñados para este caso".

Esa premisa resultó falsa, confirmado contra un `apply` real en `environments/dev`
(2026-11-11):

1. Al crear los 9 `railway_service` de `dev` (1 base de datos + 8 APIs/web), varios intentos
   fallaron con `serviceCreate ... A service named "<nombre>" already exists in this project` —
   incluso después de borrar manualmente, desde el dashboard, todos los servicios visibles bajo
   la pestaña del entorno `dev`.
2. Al revisar las pestañas `staging` y `prod` del mismo proyecto, los mismos 9 servicios con
   sufijo `-dev` aparecían ahí también (marcados "Service is offline"). Esto confirma que, en
   Railway, un "Environment" dentro de un proyecto es una vista de **despliegue**, no un límite
   de aislamiento: el objeto `service` pertenece al **proyecto completo**, y su nombre debe ser
   único a nivel de proyecto — no de entorno. El propio staff de Railway lo confirma en su foro
   oficial (station.railway.com): "Names of different services need to be unique across all
   environments" / "you can't have two different services with the same name in two different
   environments".
3. El provider de Terraform usado (`terraform-community-providers/railway` 0.6.2) tampoco envía
   `environmentId` al crear un `railway_service` (confirmado contra su código fuente,
   `internal/provider/resource_service.go`: `ServiceCreateInput{Name, ProjectId}`, sin
   `EnvironmentId`; el recurso `railway_service` no tiene ese atributo en su esquema). El propio
   staff de Railway, en otro hilo, confirma que omitir `environmentId` no limita la creación a
   un entorno: "we want to move away from deploying to all environments at once with this API".

En resumen: ni la plataforma ni el provider de Terraform usado hoy dan aislamiento real entre
entornos cuando conviven como "Environments" dentro de un mismo proyecto, para el patrón que
este repositorio necesita (un servicio con nombre propio por entorno, desplegado
independientemente). El diseño original de `research.md` 001 §3 asumía lo contrario.

## Decisión

`bootstrap/railway-project` deja de crear **un** proyecto de Railway con tres
`railway_environment`, y pasa a crear **tres proyectos de Railway independientes**, uno por
entorno de la plataforma: `maily-soft-dev`, `maily-soft-staging`, `maily-soft-production`. Cada
proyecto usa el ambiente por defecto que Railway le crea automáticamente (renombrado "dev" /
"staging" / "production" solo por claridad visual en el dashboard; el resto del repositorio
sigue referenciándolo por id, nunca por nombre).

Cada `environments/<entorno>/environment.tfvars` pasa a apuntar a su **propio** proyecto
(`railway_project_id` distinto por entorno, antes compartido entre los tres) y al ambiente por
defecto de ese proyecto (`railway_environment_id`).

`bootstrap/railway-project` expone `var.environments_to_create` (lista, default `["dev"]`) para
poder crear los proyectos de a uno, en el orden y el momento que haga falta (p. ej. `dev` hoy,
`staging` semanas después, `production` más adelante todavía) — cada `railway_project` usa
`count` sobre esa lista. Cada apply debe incluir todos los entornos que deban seguir existiendo,
no solo el nuevo: omitir uno ya creado hace que Terraform lo destruya.

Ya no hace falta crear `railway_environment` de forma explícita. Sí hace falta seguir usando
`time_sleep`/`hashicorp/time`: confirmado contra un apply real (2026-11-11) que Railway limita
`projectCreate` igual que limitaba `railway_environment` — **1 proyecto por 30 segundos por
workspace** (`"You are creating projects too quickly. This workspace allows 1 project per 30
seconds."`). `bootstrap/railway-project/main.tf` crea los tres proyectos como recursos
explícitos con un `time_sleep` de 40s entre cada uno, igual que antes se hacía entre
`railway_environment.dev` y `.staging`.

## Alternativas consideradas

- **Mantener el diseño original (un proyecto, tres Environments)**: es justo lo que
  `research.md` 001 §3 eligió; descartada porque quedó demostrado, contra un `apply` real, que
  no da el aislamiento que se buscaba y además bloquea la creación por choques de nombre a nivel
  de proyecto.
- **Un solo nombre de servicio por API, compartido entre los tres entornos, usando Railway
  Environments "como se debe"**: alinearía el repositorio con el modelo nativo real de Railway
  (un servicio, desplegado distinto por entorno), pero exige rediseñar `services.tfvars`,
  `modules/service/railway` y la convención de nombres (`mailysoft-<servicio>-<entorno>`) ya
  adoptada, perdiendo además el aislamiento operativo de poder destruir/reconstruir `dev` sin
  ningún riesgo sobre `staging`/`production` al compartir el mismo proyecto. Rechazada por ser
  un cambio mucho mayor sin resolver el problema de fondo (seguiría dependiendo de que el
  provider soportara `environmentId`, que hoy no soporta).

## Consecuencias

- `bootstrap/railway-project/main.tf` crea tres `railway_project` (uno por entorno) en vez de
  un `railway_project` + dos `railway_environment` explícitos; `outputs.tf` expone
  `project_ids`/`environment_ids` como mapas por entorno.
- Los tres `environments/<entorno>/environment.tfvars` necesitan `railway_project_id` **nuevo y
  distinto** por entorno (antes compartían el mismo valor) — requiere re-ejecutar el bootstrap y
  actualizar los tres archivos.
- El límite de 5 servicios del plan Trial de Railway ahora aplica por proyecto, es decir, por
  entorno — `dev` (9 servicios) ya no compite por ese cupo con `staging`/`production`, pero
  igual necesitará subir de plan antes de poder aplicar los 9 de golpe en un entorno Trial.
- Los *Project Tokens* (`RAILWAY_TOKEN_DEV`/`STAGING`/`PRODUCTION`) quedan acotados de forma aún
  más literal al espíritu de FR-001 ("un entorno, un proveedor"): ahora cada uno es, de verdad,
  el único token con alcance sobre ese entorno, sin ningún proyecto compartido de por medio.
  Nota: siguen sin poder crear servicios nuevos (ver `terraform-provider-railway/docs/index.md`
  — se necesita Account/Workspace Token para aprovisionar), eso no cambia con este ADR.
- `research.md` de `001-railway-deployment` sección 3 queda corregida por este ADR: la
  alternativa que ahí se rechazó ("un proyecto de Railway distinto por entorno") es, de hecho,
  la que se adopta.
