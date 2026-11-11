# ADR 0004: el backend de estado de Terraform sigue a `environment_provider`, no es siempre Azure

**Estado**: Aceptado (la decisión del backend de estado sigue vigente; la premisa de que el
*provider* `azurerm` podía quedar declarado con credenciales de relleno sin autenticarse de
verdad resultó falsa — corregida por [ADR 0005](0005-separar-roots-por-proveedor.md))
**Fecha**: 2026-11-09
**Contexto**: [specs/002-single-provider-deployment](../../specs/002-single-provider-deployment/)

## Contexto

`research.md` de `001-railway-deployment` (sección 6) decidió un único backend `azurerm`
compartido por los tres entornos, independientemente de dónde corrieran los servicios de cada
uno: en ese momento, `mailysoft-db` ya vivía en Azure, así que usar el mismo proveedor para el
estado remoto no sumaba una dependencia nueva.

Ese supuesto dejó de cumplirse con `002-single-provider-deployment`: desde que existe
`modules/database/railway-managed`, un entorno con `environment_provider = "railway"` no toca
Azure para nada — ni cómputo, ni base de datos, ni Key Vault. Hoy, los tres entornos
(`dev`, `staging`, `production`) tienen `environment_provider = "railway"`.

Al ejecutar `bootstrap/azure-backend` por primera vez (2026-11-09) se confirmó en la práctica
el costo real de esa dependencia heredada: la única suscripción de Azure disponible
(`Visual Studio Professional Subscription`) está federada al tenant de Microsoft Entra ID de
la empresa del operador, no a un tenant propio — y crear la aplicación OIDC que el backend
`azurerm` necesita (`bootstrap/azure-backend/oidc.tf`) requiere un rol de directorio
(`Application Administrator` o similar) que un empleado sin privilegios de administrador no
tiene. Forzar un entorno 100% Railway a depender de la identidad corporativa de Azure del
operador, solo para alojar el estado de Terraform, contradice el espíritu de FR-001
("un entorno, un proveedor").

## Decisión

El backend de estado remoto deja de ser siempre `azurerm` y pasa a elegirse por entorno,
igual que ya se elige `environment_provider`:

- **`environment_provider = "railway"`** (los tres entornos hoy): backend `cloud` de
  **HCP Terraform** (*free tier*), un workspace por entorno (`mailysoft-dev`,
  `mailysoft-staging`, `mailysoft-production`) en la misma organización, con
  **Execution Mode = "Local"** (HCP Terraform solo almacena y bloquea el estado; el `plan`/
  `apply` sigue corriendo en el runner de CI, igual que con `azurerm`, para no romper el
  parseo de `plan.json` que ya usan FR-010/FR-014). Autenticación con un único token de API
  (secreto de repositorio `TFC_API_TOKEN`), sin ninguna cuenta/tenant de Azure de por medio.
- **`environment_provider = "azure"`**: sigue usando el backend `azurerm` de
  `bootstrap/azure-backend`, sin cambios — ahí Azure ya es parte necesaria del entorno de
  todas formas.
- El provider `azurerm` en sí: este ADR proponía dejarlo siempre declarado en
  `environments/<entorno>/providers.tf`, con credenciales de relleno cuando
  `environment_provider != "azure"`. **Esa parte quedó corregida por
  [ADR 0005](0005-separar-roots-por-proveedor.md)**: ninguna combinación de credenciales de
  relleno evita que el provider intente autenticarse de verdad (confirmado contra tres
  intentos reales de `plan` el 2026-11-10); la solución real fue que
  `environments/<entorno>/providers.tf` deje de declarar `azurerm` por completo.
- `bootstrap/azure-backend` deja de ser un paso obligatorio del bootstrap inicial: pasa a ser
  opcional, necesario solo si algún entorno adopta `environment_provider = "azure"` (ver
  `docs/runbooks/bootstrap.md`).

## Alternativas consideradas

- **Mantener `azurerm` para todos los entornos, pero con una cuenta de Azure personal (no
  corporativa) del operador**: resuelve el 403 puntual, pero no la dependencia de fondo — un
  entorno Railway seguiría necesitando una suscripción de Azure solo para el estado, y
  cualquier otra persona/cuenta (p. ej. una cuenta de empresa del futuro) volvería a chocar
  con el mismo problema de privilegios de Entra ID. Rechazada por no resolver la causa raíz.
- **Backend `pg` sobre un Postgres de Railway dedicado al estado**: mantendría todo dentro de
  Railway, pero introduce un recurso de pago adicional (un servicio de base de datos solo
  para esto) y un backend con mucha menos tracción/herramientas que HCP Terraform o `azurerm`.
  Queda como alternativa a reconsiderar si en el futuro se quisiera eliminar también la
  dependencia de HCP Terraform como servicio externo.
- **No cambiar nada y pedir el rol de Entra ID al área de TI de la empresa**: viable, pero ata
  la infraestructura de un proyecto propio a la identidad corporativa del operador y a la
  disponibilidad de un administrador externo — rechazada por el propio operador al plantear
  esta decisión.

## Consecuencias

- `environments/{dev,staging,production}/backend.tf` usan un bloque `cloud {}` en vez de
  `backend "azurerm" {}`; cada uno requiere rellenar `organization` a mano (no puede ser una
  variable: los bloques de backend no admiten interpolación).
- `environments/{dev,staging,production}/providers.tf` configuran `azurerm` condicionalmente
  según `var.environment_provider`.
- Los tres workflows de CI (`terraform-pr.yml`, `terraform-apply.yml` vía sus dos acciones
  compuestas, `terraform-drift.yml`) leen `environment_provider` de cada
  `environment.tfvars` en tiempo de ejecución para decidir si corren `azure/login@v2`, y
  exponen `TF_TOKEN_app_terraform_io` (desde el nuevo secreto de repositorio
  `TFC_API_TOKEN`) para que `terraform init` se autentique contra HCP Terraform.
- Si en el futuro un entorno cambia a `environment_provider = "azure"`, su `backend.tf`
  individual debe cambiarse de vuelta a `backend "azurerm" {}` a mano — igual que ya ocurre
  hoy con `container_name` al añadir un entorno nuevo (README, "Añadir un entorno nuevo").
- `docs/runbooks/bootstrap.md` documenta el alta de HCP Terraform (cuenta, organización,
  workspace por entorno con Execution Mode = Local, token de API) como el nuevo paso 2 del
  bootstrap, y reclasifica `bootstrap/azure-backend` como opcional.
