# Contrato: Pipeline de despliegue (GitHub Actions)

**Spec**: [spec.md](../spec.md) | **Research**: [research.md](../research.md)

Define la interfaz de entrada/salida del pipeline de CI/CD, para que cualquier automatización o
persona que lo invoque sepa qué esperar, sin necesidad de leer su implementación interna.

## Parámetros de entrada

| Parámetro | Valores permitidos | Obligatorio | Notas |
|---|---|---|---|
| `environment` | `dev`, `staging`, `production` | sí | Determina el contenedor de estado remoto y si se exige aprobación manual (FR-009) |
| `provider` | `railway`, `azure`, `aws` | no (default `railway`) | Debe respetar el orden Railway → Azure → AWS; en esta fase, `azure`/`aws` producen el error de "no disponible aún" (FR-005), nunca un fallo inesperado |

## Eventos que disparan el pipeline

| Evento | Comportamiento |
|---|---|
| Pull request hacia `main` que modifica `environments/**` o `modules/**` | Ejecuta fmt → validate → lint → security scan → **plan**; publica el resultado del plan como comentario/artefacto en el PR. MUST NOT ejecutar `apply` (FR-008) |
| Merge a `main` (entornos `dev`/`staging`) | Ejecuta el flujo completo hasta `apply`, sin aprobación manual adicional más allá de la revisión del PR |
| Merge a `main` (entorno `production`) | Ejecuta hasta `plan`, y se detiene en un punto de aprobación manual explícita (GitHub Environment protection rule) antes de `apply` (FR-009) |
| Cron diario por entorno | Ejecuta `terraform plan -detailed-exitcode` de solo lectura; si detecta drift, abre/actualiza un issue de GitHub (FR-015). MUST NOT aplicar cambios |

## Salidas observables

| Salida | Descripción |
|---|---|
| Resultado del plan (comentario/artefacto en PR) | Resumen legible de recursos a crear/modificar/eliminar; los cambios destructivos aparecen señalados explícitamente (FR-010). MUST NOT contener valores de secretos (FR-011) |
| Estado del job de `apply` | Éxito/fallo visible en GitHub Actions; en caso de fallo, ningún cambio parcial queda aplicado sin registro en el plan correspondiente |
| Issue de drift (si aplica) | Lista los recursos cuya configuración real difiere de la definida, con enlace a la ejecución que lo detectó |

## Precondiciones

- El secreto de Railway correspondiente al `environment` solicitado MUST existir como secreto de
  **repositorio** con nombre por entorno (`RAILWAY_TOKEN_DEV`, `RAILWAY_TOKEN_STAGING`,
  `RAILWAY_TOKEN_PRODUCTION`), no como secreto de GitHub Environment: un secreto de Environment
  solo es legible por un job que declara `environment: <nombre>`, lo que activaría la aprobación
  manual de `production` (FR-009) solo para generar una previsualización de lectura en un PR,
  rompiendo "en pull requests solo se ejecuta plan" (FR-008). Ver research.md sección 2.
- Las credenciales OIDC hacia Azure (backend de estado) MUST estar configuradas para el
  repositorio, con el mismo razonamiento: no acotadas por GitHub Environment, sino por evento
  (`pull_request` / rama `main`).
- Ningún job de este pipeline se ejecuta contra `staging`/`production` desde fuera de GitHub
  Actions (Principio V: nunca desde una máquina local).
