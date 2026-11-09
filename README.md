# mailysoft-infrastructure

Infraestructura como código (IaC) de la plataforma MailySoft. Este repositorio **solo**
despliega infraestructura y pipelines; nunca construye ni modifica el código de los
microservicios (ver [constitution.md](.specify/memory/constitution.md)).

**Fase actual**: Fase 2 de la estrategia multi-nube — Railway **y** Azure operativos como
proveedor único por entorno (ver
[specs/002-single-provider-deployment](specs/002-single-provider-deployment/)); AWS llega en
una fase posterior (Principio II de la constitución).

## Estructura

```text
bootstrap/        # Terraform de un solo uso (estado local) para crear el backend remoto
                   # y el proyecto de Railway — ver docs/runbooks/bootstrap.md
modules/           # Módulos reutilizables por tipo de recurso, por proveedor
environments/      # Configuración y estado por entorno: dev, staging, production
.github/workflows/ # Pipelines de CI/CD (fmt -> validate -> lint -> security-scan -> plan -> apply)
docs/adr/          # Decisiones de arquitectura
docs/runbooks/     # Procedimientos operativos (bootstrap, rollback)
specs/             # Especificación, plan y tareas de esta fase (Spec Kit)
```

## Primeros pasos

1. Ejecutar el bootstrap una sola vez: [docs/runbooks/bootstrap.md](docs/runbooks/bootstrap.md).
2. Completar los valores pendientes (`<...>`) en `environments/*/backend.tf` y
   `environments/*/*.tfvars` con las salidas del bootstrap.
3. Abrir un PR que toque `environments/**` — el pipeline de PR generará automáticamente una
   previsualización (`terraform-pr.yml`).
4. Tras la revisión y el merge, `terraform-apply.yml` aplica a `dev`/`staging`
   automáticamente; `production` requiere aprobación manual en el GitHub Environment del
   mismo nombre.

## Añadir un servicio nuevo

Añadir una entrada al array `services` del `.tfvars` del entorno correspondiente
(`environments/<entorno>/services.tfvars`) — ver el ejemplo comentado en
[environments/dev/services.tfvars.example-new-service](environments/dev/services.tfvars.example-new-service).
**Nunca** requiere tocar nada bajo `modules/` (FR-012 de
[spec.md](specs/001-railway-deployment/spec.md)).

Campos disponibles: ver
[data-model.md](specs/001-railway-deployment/data-model.md) y el contrato de
[modules/service](modules/service/README.md).

## Añadir un entorno nuevo

1. Copiar la estructura de `environments/dev/` (`versions.tf`, `providers.tf`, `backend.tf`,
   `variables.tf`, `main.tf`) a `environments/<nuevo-entorno>/`.
2. Cambiar `container_name` en `backend.tf` a un contenedor dedicado del nuevo entorno
   (crearlo en `bootstrap/azure-backend` primero).
3. Crear `environment.tfvars`, `database.tfvars` y `services.tfvars` propios.
4. Si el entorno necesita un gate de aprobación (como `production`), crear el GitHub
   Environment correspondiente con sus reglas de protección, y añadir un job más en
   `.github/workflows/terraform-apply.yml` que lo declare.

## Elegir Railway o Azure para un entorno

Desde `002-single-provider-deployment`, cada entorno tiene un único campo
`environment_provider` (`"railway"` o `"azure"`) en su `environment.tfvars`: cambiarlo mueve
las dos aplicaciones web, las seis APIs y la base de datos de ese entorno al otro proveedor.
Un servicio individual puede seguir declarando su propio `provider` si de verdad necesita
desviarse del resto del entorno (Principio II), pero entonces el `check` de
`environments/<entorno>/main.tf` lo señala como advertencia explícita en la previsualización
(FR-014) — no es el camino silencioso por defecto. Ver
[specs/002-single-provider-deployment/spec.md](specs/002-single-provider-deployment/spec.md).

Elegir Azure exige además `azure_location` en ese mismo archivo (región de Azure para el
resource group, la VNet, el Container Apps Environment y el App Service de ese entorno — ver
[modules/network-domain/azure/README.md](modules/network-domain/azure/README.md)).

## Añadir un proveedor nuevo (AWS, Fase 3)

Ver la sección "Añadir un proveedor nuevo" de [modules/service/README.md](modules/service/README.md).
En resumen: un submódulo nuevo bajo `modules/service/<proveedor>/` con la misma interfaz, y
un bloque más en `modules/service/main.tf`. Ningún entorno existente cambia.

## Documentación relacionada

- [Especificación completa](specs/001-railway-deployment/spec.md)
- [Plan de implementación](specs/001-railway-deployment/plan.md)
- [Decisiones técnicas (research.md)](specs/001-railway-deployment/research.md)
- [Guía de validación (quickstart.md)](specs/001-railway-deployment/quickstart.md)
- [ADR 0001: provider comunitario de Railway](docs/adr/0001-railway-terraform-community-provider.md)
- [Runbook de rollback](docs/runbooks/rollback.md)
- [Fase 2 — un solo proveedor por entorno (spec, plan, research, data-model, contracts, quickstart)](specs/002-single-provider-deployment/)
- [ADR 0002: App Service + Container Apps en Azure](docs/adr/0002-azure-compute-choice.md)
- [ADR 0003: Postgres administrado en Railway, riesgo sin verificar](docs/adr/0003-railway-postgres-sin-verificar.md)
- [Diagramas de despliegue (Railway y Azure)](docs/diagrams/despliegue-mailysoft.html)
