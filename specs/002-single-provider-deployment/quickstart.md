# Quickstart: Validar un solo proveedor por entorno (Fase 2)

**Spec**: [spec.md](./spec.md) | **Data model**: [data-model.md](./data-model.md) | **Contracts**: [contracts/](./contracts/)

Esta guía valida que un entorno puede desplegarse completo en Azure (SC-001, SC-004), que ninguna
API ni la base de datos responden desde fuera en ningún proveedor (SC-002), que las tres APIs
nuevas y el frontend se incorporan solo con configuración (SC-003), que elegir Railway no toca la
base de datos existente en Azure (SC-005), y que la previsualización declara la garantía de
aislamiento activa (SC-006). Reutiliza los prerrequisitos y pasos de
[quickstart.md de la Fase 1](../001-railway-deployment/quickstart.md) para lo que no cambia
(idempotencia, drift); no se repiten aquí.

## Prerrequisitos adicionales a los de la Fase 1

- Credenciales OIDC de Azure con permiso sobre App Service, Container Apps, Virtual
  Network/Subnet/NSG y Key Vault para el entorno a probar (contracts/pipeline-contract-delta.md).
- Si se va a probar la variante `railway-managed` de la base de datos: confirmado contra el
  registro del provider el recurso de volumen persistente (research.md §3, riesgo sin verificar)
  antes de ejecutar `apply` contra un entorno real.

## 1. Desplegar un entorno completo en Azure

```bash
# environments/dev/environment.tfvars → provider = "azure"
terraform -chdir=environments/dev init -backend=true -reconfigure
terraform -chdir=environments/dev validate
terraform -chdir=environments/dev plan -out=dev.tfplan
```

**Resultado esperado**: el plan incluye las dos aplicaciones web y las seis APIs sobre recursos de
Azure (research.md §1), **sin** el error de "proveedor no disponible aún" que producía en la Fase 1
(FR-002). La salida del plan muestra `isolation_guarantee = "red"` (contracts/network-domain-interface.md).

## 2. Confirmar que las APIs y la base de datos no responden desde fuera

Tras aplicar (vía pipeline, nunca localmente contra `staging`/`production` — Principio V):

```bash
curl -m 5 https://<dominio-publico-de-maily-backoffice>/        # responde
curl -m 5 https://<lo-que-seria-el-dominio-de-maily-users-api>/ # falla: no existe, nunca tuvo dominio público
```

**Resultado esperado**: las dos aplicaciones web responden; ninguna de las seis APIs expone un
nombre público que se pueda resolver siquiera (FR-003/FR-004, SC-002). Repetir el mismo par de
comprobaciones tras desplegar el mismo entorno con `provider = "railway"` MUST dar el mismo
resultado (ninguna API con dominio público), aunque el mecanismo que lo garantiza sea distinto
(research.md §4).

## 3. Confirmar que solo las APIs llegan a la base de datos (Azure)

Desde un recurso de prueba colocado deliberadamente en `subred-web` (nunca en producción):

```bash
nc -zv -w 5 <host-privado-de-maily-db> 5432
```

**Resultado esperado**: conexión rechazada por `nsg-data` (research.md §2) — confirma que la regla
"solo las APIs" la impone la red, no solo la ausencia de credenciales, satisfaciendo FR-005.

## 4. Incorporar una API nueva solo con configuración

```bash
# Añadir la entrada de maily-clinics-api a environments/dev/services.tfvars (data-model.md)
terraform -chdir=environments/dev plan -out=dev.tfplan
```

**Resultado esperado**: el plan solo agrega el recurso de la API nueva; ningún servicio ya
desplegado aparece como `update`/`replace`/`delete` (FR-008, SC-003). Si `domain_type` se omitió en
la entrada añadida, el plan la trata como privada (FR-010) — confirmarlo en `dev.plan.json`.

## 5. Elegir Railway sin tocar la base de datos de Azure

```bash
# environments/dev/environment.tfvars → provider = "railway"
terraform -chdir=environments/dev plan -out=dev.tfplan
terraform -chdir=environments/dev show -json dev.tfplan > dev.plan.json
```

**Resultado esperado**: el plan crea un servicio y un volumen nuevos en Railway para la base de
datos de `dev` (`kind = "administrada"`, data-model.md); **ningún** recurso del plan referencia o
modifica `mailysoft-db` en Azure (FR-012, SC-005) — confirmarlo revisando que `dev.plan.json` no
contiene ninguna acción sobre el recurso/data-source de `modules/database/azure-existing`. La
salida del plan muestra `isolation_guarantee = "credenciales"`.

## 6. Provocar la advertencia de mezcla de proveedores

```bash
# environments/dev/environment.tfvars → provider = "railway"
# environments/dev/services.tfvars → forzar maily-system-api con provider = "azure"
terraform -chdir=environments/dev plan -out=dev.tfplan
```

**Resultado esperado**: el plan señala explícitamente que `maily-system-api` se desvía del
proveedor del entorno (FR-014) y el pipeline exige confirmación explícita antes de permitir el
`apply`, igual que ante cualquier cambio destructivo (contracts/pipeline-contract-delta.md).
Revertir el cambio de prueba antes de continuar.
