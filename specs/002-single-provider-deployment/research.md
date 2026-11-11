# Research: Despliegue en un Solo Proveedor — Railway o Azure (Fase 2)

**Fecha**: 2026-11-08 | **Spec**: [spec.md](./spec.md) | **Constitución**: [constitution.md](../../.specify/memory/constitution.md)

Este documento resuelve las decisiones técnicas nuevas de la Fase 2. Las decisiones ya tomadas en
la Fase 1 ([research.md de 001](../001-railway-deployment/research.md)) no se reabren aquí salvo
que se diga explícitamente: provider de Railway (§1), autenticación de pipelines (§2), modelado de
entornos en Railway (§3), tags sin soporte nativo (§5), versiones
fijadas (§7), lint/seguridad (§8) y drift/rollback (§9) siguen vigentes sin cambios. El estado
remoto siempre en `azurerm` (§6) **sí se reabre** — ver sección 6 de este documento y
[ADR 0004](../../docs/adr/0004-backend-estado-desacoplado-de-proveedor.md).

## 1. Cómputo de Azure para las ocho aplicaciones

**Decision**: Dos tipos de recurso de Azure, elegidos por el rol del servicio, no uno solo para los
ocho:
- **Las dos aplicaciones públicas** (`maily-backoffice`, `maily-frontend`): **Azure App Service**
  (Linux, contenedor), con su endpoint público nativo y *Regional VNet Integration* (saliente) hacia
  la subred `subred-apis`.
- **Las seis APIs** (`maily-users-api`, `maily-system-api`, `maily-patients-api`,
  `maily-public-api`, `maily-clinics-api`, `maily-schedule-api`): **Azure Container Apps**, dentro
  de un *Container Apps Environment* con integración de VNet desplegado en la subred `subred-apis`,
  y cada *Container App* con `ingress.external = false` (sin FQDN público por construcción).

**Rationale**: Un *Container Apps Environment* interno deja a una API sin dominio público "de
fábrica", sin pasos adicionales (FR-004) — frente a App Service, donde lograr lo mismo exige
deshabilitar el acceso público y añadir un *Private Endpoint* por servicio, repetido seis veces. App
Service, en cambio, es la opción más simple para las dos aplicaciones públicas, que sí necesitan
endpoint público nativo, dominio personalizado y los mismos patrones ya conocidos de portales
administrativos; forzarlas a Container Apps no aporta nada y complica el dominio público. Mezclar
ambos tipos detrás de la misma interfaz común de módulo (contracts/ de la Fase 1, sin cambios) no
rompe el Principio III: quien consume el módulo de servicio sigue viendo las mismas entradas/salidas
sin importar qué recurso de Azure haya detrás.

**Alternatives considered**:
- *Azure Container Apps para las ocho*: rechazado para las dos aplicaciones públicas porque
  complica innecesariamente el dominio público/certificados frente al endpoint nativo de App
  Service, sin ninguna ventaja de aislamiento para un servicio que de todas formas debe ser público.
- *Azure App Service para las ocho, con Private Endpoint en las seis APIs*: rechazado porque exige
  seis *Private Endpoints* adicionales (uno por API) para lograr lo que un *Environment* interno de
  Container Apps da sin configuración adicional; más superficie de módulo para el mismo resultado.
- *Azure Kubernetes Service (AKS)*: rechazado por desproporcionado para ocho servicios sin estado
  propio; introduciría además el único escenario donde valdría la pena usar *Application Security
  Groups* (ver spec.md, nota sobre ASG en la conversación de origen), que esta fase no necesita.

## 2. Aislamiento de red en Azure (VNet, subredes, NSG)

**Decision**: Una VNet por entorno con tres subredes: `subred-web` (las dos aplicaciones públicas,
solo para su integración VNet de salida), `subred-apis` (el *Container Apps Environment* de las seis
APIs) y `subred-data` (la base de datos, con acceso privado). Dos *Network Security Groups*:
- `nsg-apis` en `subred-apis`: permite entrada solo desde `subred-web` y desde la propia
  `subred-apis` (llamadas entre APIs); deniega cualquier otro origen, incluido internet.
- `nsg-data` en `subred-data`: permite entrada solo desde `subred-apis`; deniega cualquier otro
  origen, incluida `subred-web` — así una aplicación pública nunca alcanza la base de datos aunque
  tuviera sus credenciales (FR-005).

**Rationale**: Es la única forma, entre las evaluadas, de que "solo las APIs llegan a la base" sea
una regla que la red rechaza, no una que dependa de que nadie reparta las credenciales por error —
exactamente la garantía que Railway no puede ofrecer (research.md de 001 §4; ver también §4 de este
documento). Reutiliza el mismo patrón modular por tipo de recurso del Principio III: un módulo
`network-domain/azure` nuevo, con el mismo tipo de interfaz que ya tiene `network-domain/railway`.

**Alternatives considered**:
- *Una sola subred para todo el cómputo*: rechazada porque un NSG no puede distinguir, dentro de la
  misma subred, entre "aplicación pública" y "API" — el requisito de FR-005 exige que la red misma
  rechace a `subred-web` cuando intenta llegar a la base de datos, lo que exige subredes separadas.
  Es, además, la raíz del problema que Railway no puede resolver y que Azure sí.
- *Private Link Service en vez de subredes con NSG*: rechazado como excesivo para tráfico interno de
  un solo entorno dentro de la misma VNet; *Private Link* resuelve el caso de exponer un servicio
  *entre* VNets o a otros tenants, no el de aislar subredes de la misma red.

## 3. Base de datos nueva cuando el entorno elige Railway

**Decision**: Cuando un entorno elige Railway y todavía no tiene base de datos propia ahí (FR-011),
se modela como un `railway_service` más (el mismo recurso que ya usa `modules/service/railway` para
las aplicaciones), desplegado desde la imagen oficial de Postgres con SSL que documenta Railway, con
un volumen de Railway adjunto para persistencia. Se expone detrás de la misma interfaz de
"base de datos del entorno" que ya usa `modules/database/azure-existing`
(contracts/database-module-interface.md), para que ningún módulo consumidor necesite saber si la
base es la ya existente en Azure o una nueva en Railway.

**⚠️ Riesgo sin verificar**: no se confirmó, en esta investigación, que
`terraform-community-providers/railway` exponga un recurso de volumen persistente con el nombre y
los atributos exactos que este módulo necesitará (el provider sí expone `railway_service` de forma
genérica — research.md de 001 §1 —, pero no se encontró documentación que confirme el recurso de
volumen). **Antes del primer `apply` real de este módulo**, igual que exige el propio
`modules/service/railway/README.md` de la Fase 1, se debe confirmar el recurso exacto contra
`registry.terraform.io`; si no existe, la alternativa documentada abajo pasa a ser la decisión.

**Rationale**: Es la misma estrategia que la Fase 1 ya usa para desplegar cualquier otra cosa en
Railway (un `railway_service` desde una imagen, más variables de entorno) — no introduce un
mecanismo nuevo de aprovisionamiento, solo una imagen y un volumen distintos. Mantiene el Principio
II: la base de datos ya existente en Azure (`mailysoft-db`) nunca se toca; esta es una base
*distinta*, propia del entorno que eligió Railway (FR-012).

**Alternatives considered**:
- *Plantilla/plugin oficial de Postgres de Railway*: Railway ofrece una plantilla de un clic desde
  su catálogo, pero no se encontró evidencia de que el provider comunitario de Terraform pueda
  desplegarla como tal (a diferencia de un `railway_service` genérico); se deja como alternativa a
  reconsiderar solo si, al verificar el riesgo señalado arriba, el volumen persistente tampoco
  resulta soportado por el provider.
- *Usar siempre la base de datos de Azure incluso cuando el entorno elige Railway*: rechazada porque
  contradice directamente el objetivo de esta fase (FR-001: todo el entorno en un solo proveedor) y
  porque mezclaría silenciosamente proveedores sin pasar por la advertencia explícita que exige
  FR-014.

## 4. Declarar la garantía de aislamiento en la previsualización

**Decision**: Cada implementación del módulo `network-domain` (`railway`, `azure`) expone un output
nuevo `isolation_guarantee`, con valor fijo `"credenciales"` para `railway` y `"red"` para `azure`.
El entorno (`environments/<nombre>/main.tf`) lo vuelve a exponer como output raíz, y el pipeline ya
existente (contracts/pipeline-contract-delta.md) lo imprime junto al resumen de la previsualización,
sin necesidad de un paso nuevo de CI.

**Rationale**: Reutiliza el mecanismo de outputs de Terraform que ya existe para
`provider_available` (contracts/service-module-interface.md de la Fase 1) en vez de inventar un
canal nuevo de reporte; satisface FR-007 con el menor cambio posible sobre el pipeline ya construido
en la Fase 1.

**Alternatives considered**:
- *Documentarlo solo en el README/runbook, sin output de Terraform*: rechazado porque no aparecería
  en la previsualización de cada cambio (FR-007 exige que se muestre ahí, no solo en documentación
  estática que alguien podría no leer antes de aprobar).

## 5. Identidad de los servicios de Azure hacia Key Vault

**Decision**: Cada aplicación/API de Azure (App Service o Container App) obtiene una *Managed
Identity* asignada por el sistema, con permiso de solo lectura sobre los secretos que necesita en el
Key Vault ya referenciado por la Fase 1 (`azure_key_vault_id`), en vez de recibir el valor del
secreto como variable de entorno plana resuelta por el pipeline.

**Rationale**: Es el mecanismo de mínimo privilegio y "sin credenciales de larga duración" que el
Principio VI ya exige y que Azure sí soporta de forma nativa (igual que la Fase 1 ya eligió OIDC
para el backend de estado, research.md de 001 §2, por la misma razón). Refuerza además FR-006: solo
las seis APIs reciben una identidad con permiso de lectura sobre el secreto de conexión a la base de
datos; las dos aplicaciones públicas nunca obtienen ese permiso.

**Alternatives considered**:
- *Seguir resolviendo el secreto en el pipeline e inyectarlo como variable de entorno*, igual que en
  Railway: rechazada como destino final para Azure porque renunciaría, sin necesidad, a una
  capacidad de mínimo privilegio que el proveedor ya ofrece de forma nativa y gratuita.

**Nota de implementación (alcance de este pase)**: la primera implementación de
`modules/service/azure` (T014-T017) añade la identidad administrada asignada por el sistema en
cada recurso (groundwork para esta decisión), pero mantiene el mismo flujo de secretos ya
resuelto como valor y entregado como variable de entorno que usa Railway, para no introducir dos
arquitecturas de secretos distintas en el mismo cambio. Cablear el acceso a Key Vault vía
`azurerm_role_assignment` y la sintaxis de referencia `@Microsoft.KeyVault(...)` queda como
trabajo de seguimiento explícito, no como parte de esta fase.

## 6. (Revisión) Estado remoto de Terraform cuando el entorno elige Railway

**Decision**: Se reabre research.md de 001 §6. El backend de estado deja de ser siempre
`azurerm`: ahora sigue a `environment_provider`, igual que el resto de la infraestructura de
cada entorno. Con `environment_provider = "railway"` (los tres entornos hoy), el backend es
`cloud` de HCP Terraform (*free tier*, un workspace por entorno, Execution Mode = "Local"),
autenticado con un único token de API (`TFC_API_TOKEN`). Con `environment_provider = "azure"`,
se mantiene `azurerm` tal como describía 001 §6, vía `bootstrap/azure-backend` (que pasa a ser
opcional, no un paso obligatorio del bootstrap inicial). Detalle completo, motivación y
consecuencias en [ADR 0004](../../docs/adr/0004-backend-estado-desacoplado-de-proveedor.md).

**Rationale**: 001 §6 asumía que `mailysoft-db` ya vivía en Azure, así que alojar ahí también
el estado no sumaba una dependencia nueva. Ese supuesto no aplica a un entorno con
`environment_provider = "railway"` desde que existe `modules/database/railway-managed`
(sección 3 de este documento): hoy ese entorno no toca Azure para nada más. Mantener el
backend fijo en `azurerm` para los tres entornos, descubierto en la práctica (2026-11-09),
fuerza a cualquier operador a depender de una identidad de Microsoft Entra ID (potencialmente
la de un empleador, no propia) solo para guardar un archivo de estado — justo el tipo de
acoplamiento innecesario entre proveedores que FR-001 busca evitar.

**Alternatives considered**: ver ADR 0004.
