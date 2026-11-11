# Research: Despliegue Automatizado de MailySoft en Railway (Fase 1)

**Fecha**: 2026-10-24 | **Spec**: [spec.md](./spec.md) | **Constitución**: [constitution.md](../../.specify/memory/constitution.md)

Este documento resuelve las decisiones técnicas necesarias para implementar la Fase 1 (Railway) de
la estrategia multi-nube, dentro de los límites fijados por la constitución del repositorio.

## 1. Provider de Terraform para Railway

**Decision**: Usar el provider comunitario `terraform-community-providers/railway` (no existe un
provider oficial mantenido por Railway), fijando su versión exacta en `versions.tf` y en el
lockfile `.terraform.lock.hcl` commiteado al repositorio.

**Rationale**: La constitución (Principio III) exige Terraform como única fuente de verdad y
prohíbe cambios manuales en consola; no existe alternativa oficial. El provider comunitario expone
los recursos necesarios (`railway_project`, `railway_environment`, `railway_service`,
`railway_variable`, dominios) para cubrir FR-001, FR-002 y FR-007.

**Riesgo conocido y mitigación**: El personal de Railway ha declarado públicamente que no
recomienda IaC sobre su plataforma y sugiere el dashboard o `railway.toml`; además se han reportado
errores 503 de la API de Railway al gestionar más de ~50-70 recursos en una sola operación. Dado
que la constitución no permite abandonar Terraform ni usar la consola manualmente, se acepta el
riesgo con las siguientes mitigaciones, que se detallan como tareas de implementación:
- Fijar una versión concreta y probada del provider antes de cada fase de servicios nuevos.
- Aplicar cambios en lotes pequeños (por servicio o grupo reducido), no en una sola operación
  masiva sobre todos los servicios y entornos a la vez.
- Documentar un procedimiento de recuperación manual (re-`import` + `apply`) para el caso en que la
  API de Railway quede en un estado inconsistente tras un error 503.
- Registrar esta decisión como ADR (ver FR-014 / Principio VIII) una vez iniciada la implementación.

**Alternatives considered**:
- *Usar `railway.toml` o el dashboard de Railway*: rechazado porque viola directamente el
  Principio III (Terraform como única fuente de verdad) y el Principio I (nunca crear/modificar
  recursos manualmente).
- *Esperar a un provider oficial*: rechazado porque bloquearía indefinidamente la Fase 1 sin fecha
  conocida de disponibilidad.

## 2. Autenticación de pipelines contra Railway y Azure

**Decision**:
- **Railway**: usar *Project Tokens* (`RAILWAY_TOKEN`), que Railway limita a un único proyecto y
  **entorno** (dev, staging o production), no un token de cuenta u organización. Un token por
  entorno, guardado como **secreto a nivel de repositorio con nombre por entorno**
  (`RAILWAY_TOKEN_DEV`, `RAILWAY_TOKEN_STAGING`, `RAILWAY_TOKEN_PRODUCTION`), no como secreto
  de GitHub Environment. Razón (descubierta durante la implementación, T025/T034): un secreto de
  GitHub Environment solo es legible por un job que declara `environment: <nombre>`, pero
  declarar `environment: production` en el job de *plan* de un PR activaría la regla de
  aprobación manual de ese entorno (T034) solo para generar una previsualización de lectura,
  rompiendo "en pull requests solo se ejecuta plan" (FR-008). El job de `apply` sobre
  `production` sigue declarando `environment: production` únicamente para activar el gate de
  aprobación (FR-009); el secreto en sí se lee como secreto de repositorio, no por el gate.
- **Azure** (backend de estado remoto, Key Vault con credenciales de `mailysoft-db`): usar
  autenticación OIDC (Workload Identity Federation) entre GitHub Actions y Microsoft Entra ID, sin
  credenciales de larga duración.

**Rationale**: Railway no ofrece federación OIDC para sus pipelines (no se encontró ninguna
referencia en su documentación pública); su propio modelo de tokens ya permite acotar el alcance a
un solo entorno, lo que satisface el principio de mínimo privilegio disponible para ese proveedor.
Azure sí soporta OIDC de forma nativa con GitHub Actions, por lo que se usa ahí tal como exige el
Principio VI ("autenticación preferente sin credenciales de larga duración... donde el proveedor lo
permita").

**Alternatives considered**:
- *Un único token de cuenta de Railway para todos los entornos*: rechazado por violar mínimo
  privilegio (un token comprometido afectaría los tres entornos, incluido production).
- *Service Principal de Azure con secreto estático*: rechazado porque Azure sí soporta OIDC; usar
  un secreto de larga duración sería una regresión innecesaria frente al Principio VI.

## 3. Modelado de entornos y proyecto en Railway

> **Corregido por [ADR 0006](../../docs/adr/0006-un-proyecto-railway-por-entorno.md)
> (2026-11-11)**: la decisión de abajo (un único proyecto con tres Railway Environments) resultó
> no dar aislamiento real entre entornos, confirmado contra un `apply` real — un `railway_service`
> creado "para dev" queda visible y con el mismo nombre reservado en las demás pestañas del mismo
> proyecto, porque el objeto pertenece al proyecto completo, no al Environment. El ADR 0006 adopta
> en su lugar la alternativa que aquí se había rechazado: un proyecto de Railway distinto por
> entorno. El resto de esta sección queda como registro histórico de la decisión original.

**Decision**: Un único proyecto de Railway (`mailysoft`) con tres **Railway Environments** nativos
(`dev`, `staging`, `production`), uno por cada entorno de la plataforma. Cada servicio de MailySoft
se replica como un servicio independiente dentro de cada Railway Environment.

**Rationale**: Railway ya tiene el concepto nativo de "Environment" dentro de un proyecto, con
variables compartidas (*Shared Variables*) acotadas a proyecto+entorno — ideal para distribuir el
dato de conexión a la base de datos de Azure a todas las APIs de un mismo entorno sin duplicarlo
por servicio. Los *Project Tokens* de Railway se acotan precisamente a un proyecto+entorno, lo que
alinea el modelo de autenticación (decisión 2) con el modelo de recursos.

**Alternatives considered**:
- *Un proyecto de Railway distinto por entorno*: rechazado porque fragmenta la gestión de variables
  compartidas y no aporta aislamiento adicional frente a usar Environments nativos, que ya están
  diseñados para este caso.

## 4. Redes y dominios (público / privado)

**Decision**: Mapear el atributo "tipo de dominio" de cada servicio (FR-001) así:
- **Público**: habilitar *Public Networking* de Railway (dominio autogenerado `*.up.railway.app` o
  dominio personalizado vía CNAME+TXT, con SSL automático).
- **Privado**: no generar dominio público; el servicio permanece accesible solo vía *Private
  Networking* (mesh WireGuard interno, activo por defecto), direccionable como
  `<servicio>.railway.internal` dentro del mismo Railway Environment.

**Rationale**: Railway ofrece ambos mecanismos de forma nativa y gratuita dentro de un mismo
entorno; no se requiere un componente adicional (ni balanceador, ni VPN propia) para lograr el
aislamiento de red que piden los servicios internos (ej. `mailysoft-sistema-api` si no debe ser
pública).

**Alternatives considered**: ninguna evaluada — el mecanismo nativo cubre el requisito sin
complejidad adicional.

## 5. Etiquetado obligatorio (Principio VII) en un proveedor sin tags nativas

**Decision**: Railway no ofrece un sistema de etiquetas (*tags*) de clave-valor como Azure o AWS.
Las cinco etiquetas obligatorias (`proyecto`, `servicio`, `entorno`, `propietario`,
`gestionado-por=terraform`) se implementan como:
1. Convención de nombres (`mailysoft-<servicio>-<entorno>`) que ya codifica proyecto/servicio/
   entorno en el propio nombre del recurso.
2. Un bloque de variables de introspección no sensibles (`TAG_PROYECTO`, `TAG_SERVICIO`,
   `TAG_ENTORNO`, `TAG_PROPIETARIO`, `TAG_GESTIONADO_POR`) inyectado por el módulo común a cada
   servicio, visible para quien inspeccione el servicio desde Railway.
3. El propio código y estado de Terraform como registro canónico y consultable de las etiquetas
   de cada recurso (coherente con el Principio III: Terraform es la única fuente de verdad).

**Rationale**: Dado que el proveedor no persiste tags arbitrarias, la combinación de nombre +
variables de introspección + Terraform como fuente de verdad reproduce el mismo propósito
(trazabilidad de propiedad/costo/entorno) sin depender de una capacidad que Railway no ofrece.

**Alternatives considered**:
- *Omitir las etiquetas en Railway*: rechazado porque contradice directamente el Principio VII.
- *Mantener un archivo externo de mapeo de tags*: rechazado por añadir una fuente de verdad
  adicional fuera de Terraform, lo que contradice el Principio III.

## 6. Estado remoto de Terraform

**Decision**: Backend `azurerm` (Azure Storage Account + contenedor Blob), con un **contenedor
separado por entorno** (`tfstate-dev`, `tfstate-staging`, `tfstate-production`) dentro de la misma
cuenta de almacenamiento. Bloqueo mediante el lease nativo de Blob Storage (soportado de forma
nativa por el backend `azurerm`); cifrado en reposo mediante cifrado de Storage Account (claves
administradas por Microsoft, suficiente para esta fase). Acceso desde GitHub Actions vía OIDC
(decisión 2).

**Rationale**: Satisface el Principio III (estado remoto, bloqueo, cifrado, separado por entorno)
usando el mismo proveedor (Azure) donde ya vive `mailysoft-db`, sin introducir un cuarto proveedor
solo para alojar el estado.

**Alternatives considered**:
- *HCP Terraform / Terraform Cloud como backend*: rechazado en esta fase para no introducir una
  dependencia y una facturación adicional cuando Azure ya cubre el requisito sin costo incremental
  relevante; puede reconsiderarse en una fase posterior si se requiere una UI de gestión de estado
  más rica.
- *Backend local o en el propio repositorio Git*: rechazado por violar directamente el requisito de
  estado remoto con bloqueo y cifrado.

## 7. Versión de Terraform y providers

**Decision**: Fijar `required_version = "~> 1.15.0"` en `versions.tf` para la CLI de Terraform, y
fijar versión exacta de cada provider (`terraform-community-providers/railway`,
`hashicorp/azurerm`) en el mismo archivo, con `.terraform.lock.hcl` commiteado al repositorio. El
patch exacto dentro de la línea 1.15.x se debe confirmar contra releases.hashicorp.com en el
momento de la primera implementación, dado que la cadencia de releases de Terraform es alta.

**Rationale**: El Principio III exige versiones fijadas de Terraform y de cada provider para
garantizar builds reproducibles.

**Alternatives considered**: usar un rango abierto (`>= 1.x`) — rechazado explícitamente por el
Principio III.

## 8. Linting y análisis de seguridad en el pipeline

**Decision**: `tflint` para la etapa de lint (reglas de Terraform: nombres, variables no usadas,
convenciones) y `Checkov` para la etapa de análisis de seguridad (cobertura profunda de políticas
específicas de Terraform, incluyendo reglas sobre cifrado y exposición de recursos).

**Rationale**: `tfsec` fue absorbido por Trivy y ya no recibe nuevas reglas de forma independiente;
Checkov mantiene la cobertura de políticas más profunda específicamente para Terraform entre las
herramientas activas evaluadas, y tiene una GitHub Action oficial lista para integrarse en el flujo
fmt→validate→lint→security-scan→plan exigido por el Principio V.

**Alternatives considered**:
- *tfsec*: rechazado por estar en modo de mantenimiento, sin nuevas reglas.
- *Trivy* (sucesor de tfsec): considerado válido como alternativa futura si se necesita un único
  escáner que cubra también secretos y contenedores; se deja como posible evolución, no como
  elección inicial, para mantener el alcance de esta fase acotado a Terraform.

## 9. Detección de drift y rollback

**Decision**:
- **Drift**: workflow de GitHub Actions programado (cron diario) por entorno que ejecuta
  `terraform plan -detailed-exitcode -lock=false` en modo solo lectura; si el código de salida es
  `2` (cambios detectados), el workflow abre o actualiza un *issue* de GitHub describiendo el
  recurso afectado, sin aplicar ningún cambio automáticamente (FR-015).
- **Rollback**: procedimiento documentado de "volver a aplicar la última configuración estable
  conocida": `git revert` (o checkout del último tag/commit marcado como estable) sobre el
  repositorio de infraestructura, seguido del flujo normal plan→revisión→apply contra ese estado
  previo (FR-013).

**Rationale**: Reutiliza el mismo flujo de pipeline ya exigido por el Principio V, sin introducir
herramientas de rollback o de detección de drift adicionales.

**Alternatives considered**: corrección automática de drift (`terraform apply` automático al
detectar diferencias) — rechazada explícitamente porque el Principio V exige revisión humana y
aprobación antes de cualquier `apply`, y el spec (FR-015) pide solo reportar, no corregir
automáticamente.
