# modules/service/azure

Implementación Azure del módulo de servicio (contrato común en
[contracts/service-module-interface.md](../../../specs/001-railway-deployment/contracts/service-module-interface.md)).
Operativa desde `002-single-provider-deployment` (antes era un stub que siempre fallaba —
FR-005 de `001-railway-deployment`).

## Qué crea

- `domain_type = "public"` (`maily-backoffice`, `maily-frontend`): un `azurerm_service_plan`
  (Linux) + `azurerm_linux_web_app`, con integración de VNet de salida hacia `subred-web` e
  identidad administrada asignada por el sistema.
- `domain_type = "private"` (las seis APIs): un `azurerm_container_app` dentro del
  *Container Apps Environment* **compartido** que crea `modules/network-domain/azure` (una
  sola vez por entorno — este módulo nunca crea su propio *Environment*), con
  `ingress.external_enabled = false` (FR-004: sin FQDN público).

## Entradas que no vienen de la Fase 1

- `container_image`: a diferencia de Railway (que construye nativamente desde `source_repo`
  vía Nixpacks), Azure App Service/Container Apps exigen una imagen ya construida. Si se
  omite, se deriva de `source_repo`/`source_ref` reemplazando `github.com/` por `ghcr.io/` —
  válido solo si el microservicio publica ahí con esa convención; si no, declarar este campo
  explícitamente en la entrada de `services.tfvars` correspondiente.
- `network`: la salida `compute_network_refs` de `modules/network-domain/azure`
  (resource group, ubicación, ids de subred y del *Container Apps Environment*). Obligatoria.

## Pendiente de seguimiento (no en este pase)

La identidad administrada ya se declara en ambos recursos, pero el acceso a Key Vault sigue
resolviéndose como valor ya inyectado por el entorno (`database_connection.secret_ref`), igual
que en Railway — no vía `azurerm_role_assignment` + referencia nativa `@Microsoft.KeyVault(...)`.
Ver research.md §5 ("Nota de implementación").

## Ejemplo de uso

Ver `modules/service/README.md` para el ejemplo completo del módulo fachada; este módulo no
se invoca directamente desde ningún entorno, siempre a través de `modules/service`.
