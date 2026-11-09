# modules/network-domain/azure

Implementación Azure de la interfaz común de "red de aislamiento" — contrato completo en
[contracts/network-domain-interface.md](../../../specs/002-single-provider-deployment/contracts/network-domain-interface.md).
A diferencia de `modules/network-domain/railway` (que se instancia una vez **por servicio**
desde dentro de `modules/service/railway`), este módulo se instancia **una sola vez por
entorno**, desde `environments/<entorno>/main.tf`, porque sus recursos (VNet, subredes, NSG,
Container Apps Environment) son compartidos por las ocho aplicaciones de ese entorno.

## Qué crea

- Un resource group dedicado (`mailysoft-red-<entorno>`) y una VNet (`mailysoft-vnet-<entorno>`,
  `10.20.0.0/16` por omisión) con tres subredes `/24`: `subred-web`, `subred-apis`,
  `subred-data`.
- `nsg-apis`: permite entrada a `subred-apis` solo desde `subred-web` y desde sí misma; deniega
  el resto (FR-005).
- `nsg-data` (solo si `database_requires_isolation = true`): permite entrada a `subred-data`
  solo desde `subred-apis`; deniega el resto, incluida `subred-web` — así una aplicación
  pública nunca alcanza la base de datos aunque tuviera sus credenciales.
- Un `Container Apps Environment` compartido, integrado en `subred-apis`, con
  `internal_load_balancer_enabled = true` (sin IP pública de entrada para el *Environment*
  completo).

## Entradas / Salidas

Ver variables.tf/outputs.tf y el contrato común enlazado arriba. `isolation_guarantee` es
siempre `"red"` en esta implementación.

## Ejemplo de uso

```hcl
module "azure_network" {
  source = "../../modules/network-domain/azure"
  count  = var.environment_provider == "azure" ? 1 : 0

  environment_name            = var.environment_name
  location                    = var.azure_location
  public_service_names        = [for s in var.services : s.name if s.enabled && s.domain_type == "public"]
  private_service_names       = [for s in var.services : s.name if s.enabled && s.domain_type != "public"]
  database_requires_isolation = anytrue([for s in var.services : s.requires_database])

  tags = {
    proyecto       = "mailysoft"
    servicio       = "red"
    entorno        = var.environment_name
    propietario    = "equipo-plataforma"
    gestionado_por = "terraform"
  }
}
```

## Pendiente de verificación

Los nombres y atributos de los recursos `azurerm_*` usados aquí (VNet, Subnet, NSG, Container
App Environment) corresponden a la versión de `hashicorp/azurerm` ya fijada en
`environments/*/versions.tf` (`4.15.0`) y son estables desde hace varias versiones mayores —
a diferencia del provider comunitario de Railway, no llevan la misma advertencia de
verificación pendiente. Aun así, confirmar `internal_load_balancer_enabled` y el bloque
`delegation` de `Microsoft.App/environments` contra la documentación de `azurerm` vigente al
momento de implementar, por si la versión fijada cambiara ese nombre.
