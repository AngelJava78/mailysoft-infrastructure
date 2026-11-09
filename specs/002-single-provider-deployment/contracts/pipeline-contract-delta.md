# Contrato: Delta sobre el pipeline de despliegue (GitHub Actions)

**Spec**: [spec.md](../spec.md) | **Contrato base**: [pipeline-contract.md de la Fase 1](../../001-railway-deployment/contracts/pipeline-contract.md)

Este documento describe únicamente lo que cambia sobre el contrato de pipeline ya definido en la
Fase 1. Todo lo que no se menciona aquí (eventos que disparan el pipeline, precondiciones de
secretos, aprobación manual en `production`) sigue vigente sin cambios.

## Parámetros de entrada — cambia el comportamiento de uno existente

| Parámetro | Antes (Fase 1) | Ahora (Fase 2) |
|---|---|---|
| `provider` | `azure`/`aws` producían siempre el error "no disponible aún" (FR-005 de la Fase 1) | `azure` queda operativo (FR-002 de esta fase); `aws` sigue produciendo ese mismo error (Fase 3, fuera de alcance) |

No se añade ningún parámetro nuevo: el modo "un solo proveedor por entorno" (FR-001) se configura en
`environment.tfvars` (data-model.md), no como un parámetro adicional del pipeline.

## Salidas observables — se añade una fila nueva

| Salida | Descripción |
|---|---|
| **Garantía de aislamiento del entorno** *(nueva)* | El pipeline imprime, junto al resumen del plan, el valor de `isolation_guarantee` (contracts/network-domain-interface.md): `"red"` o `"credenciales"`, para que quien revisa sepa cuál de las dos aplica antes de aprobar (FR-007, SC-006) |
| Resultado del plan | Sin cambios respecto a la Fase 1, salvo que ahora también se usa para advertir mezcla de proveedores (ver abajo) |

## Gate de aprobación — se añade una condición nueva

| Condición | Comportamiento |
|---|---|
| El plan reporta que algún servicio o la base de datos de un entorno tiene un `provider` distinto al `environment.provider` configurado (FR-014) | El pipeline MUST tratarlo igual que un cambio destructivo ya existente (contracts/pipeline-contract.md de la Fase 1, fila de "Resultado del plan"): señalarlo explícitamente y exigir aprobación explícita antes de `apply`, **en cualquier entorno**, no solo en `production` |
| Cambiar el `provider` de un entorno ya desplegado (FR-015) | El plan resultante reemplaza todos los servicios y la base de datos de ese entorno; se señala como cambio destructivo (mismo mecanismo que FR-010 de la Fase 1), con aprobación explícita obligatoria en cualquier entorno |

## Precondiciones — se añade una nueva

- Cuando `environment.provider = azure` para un entorno, las credenciales OIDC hacia Azure
  (ya configuradas desde la Fase 1 para el backend de estado) MUST tener además permiso para
  gestionar los recursos de cómputo y de red de este plan (App Service, Container Apps, Virtual
  Network, Subnet, Network Security Group, Key Vault), con el mismo principio de mínimo privilegio
  ya exigido (Principio VI; research.md §5).
