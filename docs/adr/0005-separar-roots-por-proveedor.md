# ADR 0005: `environments/<entorno>` es un root de Terraform 100% Railway; Azure exigiría un root distinto

**Estado**: Aceptado
**Fecha**: 2026-11-10
**Contexto**: [specs/002-single-provider-deployment](../../specs/002-single-provider-deployment/)
**Corrige en parte a**: [ADR 0004](0004-backend-estado-desacoplado-de-proveedor.md)

## Contexto

ADR 0004 resolvió el backend de estado (ya no depende de Azure), pero asumió que el provider
`azurerm` en sí podía quedar declarado siempre en `environments/<entorno>/providers.tf`,
configurado con credenciales de relleno cuando `environment_provider != "azure"`, sin que eso
intentara autenticarse contra nada real.

Esa suposición resultó falsa, confirmado contra tres intentos reales de `terraform plan` en
`environments/dev` (2026-11-10):

1. Con solo un `subscription_id` de relleno: el provider cae al fallback de Azure CLI
   (`use_cli`, activo por omisión) e intenta usar la sesión real de `az login` de quien
   ejecuta el plan — falló porque esa suscripción de relleno no existe ahí.
2. Desactivando `use_cli` y dando `client_id`/`client_secret`/`tenant_id` de relleno: el
   provider intentó un *client credentials grant* real contra Microsoft Entra ID
   (`clientCredentialsToken`), que respondió `AADSTS700038: ... is not a valid application
   identifier` — una llamada de red real, no una validación local.

Conclusión: **no existe ninguna combinación de credenciales de relleno que deje a `azurerm`
"inofensivo"**. En cuanto Terraform configura ese provider (lo hace siempre que el bloque
exista en el root, o que cualquier módulo referenciado estáticamente en el árbol —incluso con
`count = 0`— lo requiera en su propio `required_providers`), intenta autenticarse de verdad.
Esto se confirmó también para la validación de variables de `modules/service/aws` (ver
`modules/service/aws/variables.tf`): una variable con una validación, referenciada
estáticamente aunque sea en un módulo con `count = 0`, se evalúa igual.

## Decisión

`environments/{dev,staging,production}/` dejan de ser roots "multi-proveedor con
`environment_provider` como interruptor" y pasan a ser roots **100% Railway, por
construcción**:

- `providers.tf`: solo declara `provider "railway"`. Sin `provider "azurerm"`.
- `versions.tf`: sin `azurerm` en `required_providers`.
- `main.tf`: ya no llama al despachador genérico `modules/service` (que referencia
  estáticamente `modules/service/azure` y `modules/service/aws`, forzando el problema de
  arriba); llama directamente a `modules/service/railway` por cada entrada *enabled* de
  `services.tfvars`. Tampoco instancia `modules/database/azure-existing` ni
  `modules/network-domain/azure` — la base de datos siempre es
  `modules/database/railway-managed`.
- `variables.tf`: `environment_provider` solo acepta `"railway"` (antes `"railway"` o
  `"azure"`); un servicio con `provider` explícito a otro valor es ahora un **error duro de
  validación** (antes, un `check` que solo advertía — FR-014). No tiene sentido aceptar un
  valor que este root no puede honrar sin desplegarlo silenciosamente en el lugar equivocado.
  Las variables `azure_resource_group_name`, `azure_db_server_name`, `azure_db_server_type`,
  `azure_db_database_name`, `azure_key_vault_id` y `azure_location` se eliminan: no hay nada
  que las use.
- `database.tfvars`: queda vacío en los tres entornos (se sigue pasando con `-var-file` por
  consistencia con el pipeline, pero no declara nada).

`modules/service` (el despachador), `modules/service/azure`, `modules/database/azure-existing`
y `modules/network-domain/azure` **no se eliminan** del repositorio: quedan intactos, sin
ninguna referencia desde los tres entornos actuales. Representan el trabajo ya hecho de la
Fase 2 para Azure, listo para cuando exista un root que realmente lo necesite.

## Alternativas consideradas

- **Mantener un único root con `environment_provider` como interruptor, usando credenciales
  de relleno para `azurerm`**: es lo que intentaba ADR 0004; descartada porque, confirmado
  empíricamente, no hay forma de que esas credenciales no disparen una autenticación real.
- **Usar una suscripción de Azure gratuita y real (aunque vacía) solo para que el provider
  pueda autenticarse**: resolvía el síntoma sin tocar la estructura, pero mantiene una
  dependencia de Azure (aunque sea gratuita) para un entorno que no usa ningún recurso de
  Azure — rechazada explícitamente por el operador al plantear esta decisión.
- **Alias de provider (`provider "azurerm" { alias = "..." }`) en vez de uno por omisión**:
  no resuelve el problema de fondo, porque la causa confirmada es la *presencia estática* de
  un módulo que requiere el provider en el árbol de configuración, no si ese provider tiene
  alias o no.

## Consecuencias

- Elegir Azure para un entorno ya **no es cambiar un único valor** en `environment.tfvars`
  (como describía la Fase 2 original, FR-001) — requiere crear un root de Terraform distinto
  para ese entorno, que sí declare `provider "azurerm"` y use el despachador `modules/service`
  completo. Ese root todavía no existe en el repositorio (YAGNI: ningún entorno lo necesita
  hoy); construirlo es trabajo de seguimiento explícito cuando haga falta, no parte de este
  cambio.
- `bootstrap/azure-backend` sigue existiendo y sigue siendo opcional, pero ahora lo es con más
  motivo: ni siquiera el *provider* de Azure se declara en los roots actuales, no solo el
  backend de estado.
- El `check "provider_consistency"` (FR-014) desaparece de los tres `main.tf`: ya no hace
  falta, porque la validación dura en `variables.tf` impide por completo que un servicio
  declare un `provider` que este root no puede servir.
- `modules/service/railway`'s contrato de entrada se vuelve la interfaz directa que
  `environments/<entorno>/main.tf` consume (antes era `modules/service`, el despachador,
  quien la consumía). `modules/service/README.md` sigue describiendo el despachador para
  cuando un root multi-proveedor lo necesite.
