# Quickstart: Validar el despliegue en Railway (Fase 1)

**Spec**: [spec.md](./spec.md) | **Data model**: [data-model.md](./data-model.md) | **Contracts**: [contracts/](./contracts/)

Esta guía valida, de extremo a extremo, que el entorno `dev` puede desplegarse en Railway sin
pasos manuales en consola (SC-001), que las APIs se conectan a la base de datos de Azure (SC-006),
y que aplicar dos veces la misma configuración es idempotente (SC-005).

## Prerrequisitos

- Acceso al proyecto Railway `mailysoft` con un *Project Token* para el entorno `dev`
  (ver [research.md](./research.md) §2-3), guardado como secreto de repositorio
  `RAILWAY_TOKEN_DEV` (no como secreto de GitHub Environment — ver research.md §2).
- Acceso de lectura a Azure Key Vault con el secreto de conexión de `mailysoft-db`, vía identidad
  OIDC ya configurada para el repositorio.
- Terraform instalado en la versión fijada en `versions.tf` (ver research.md §7).
- `tflint` y `checkov` instalados localmente si se quiere reproducir el pipeline antes de abrir el
  PR (opcional; el pipeline los ejecuta igualmente en CI).

## 1. Validar la configuración (local o en PR)

```bash
terraform -chdir=environments/dev fmt -check
terraform -chdir=environments/dev init -backend=true
terraform -chdir=environments/dev validate
tflint --chdir=environments/dev
checkov -d environments/dev
```

**Resultado esperado**: todos los comandos terminan sin errores. Si `services.tfvars` tiene un
servicio con `provider = "azure"` o `"aws"`, `validate` MUST fallar con el mensaje de "proveedor no
disponible aún" (FR-005) — esto es el comportamiento correcto, no un defecto.

## 2. Generar y revisar la previsualización

```bash
terraform -chdir=environments/dev plan -out=dev.tfplan
terraform -chdir=environments/dev show -json dev.tfplan > dev.plan.json
```

**Resultado esperado**: la previsualización lista los servicios habilitados en
`environments/dev/services.tfvars` como recursos a crear. Si algún cambio elimina o reemplaza un
recurso existente, debe aparecer señalado como tal (FR-010) — confirmarlo inspeccionando las
acciones `delete`/`replace` en `dev.plan.json`. Ningún valor de `secret_refs` debe aparecer en
texto plano en esta salida (FR-011).

## 3. Aplicar (tras aprobación, vía pipeline)

En un entorno real esto ocurre solo a través del pipeline (ver
[contracts/pipeline-contract.md](./contracts/pipeline-contract.md)), nunca desde una máquina
local hacia `staging`/`production`. Para `dev`, tras la revisión del PR:

```bash
terraform -chdir=environments/dev apply dev.tfplan
```

**Resultado esperado**: los servicios habilitados quedan desplegados en el Railway Environment
`dev` del proyecto `mailysoft`, sin haber abierto el dashboard de Railway (SC-001).

## 4. Verificar conectividad a la base de datos de Azure

Para cada servicio con `requires_database = true` (ej. `mailysoft-pacientes-api`):

```bash
railway run --service mailysoft-pacientes-api-dev -- python -c "import os; print('DB host:', os.environ.get('DATABASE_HOST'))"
```

**Resultado esperado**: el servicio resuelve la variable de conexión inyectada desde el secreto de
Azure Key Vault y puede alcanzar `mailysoft-db` (SC-006), sin que el pipeline haya creado, movido
ni destruido esa base de datos (FR-006).

## 5. Verificar idempotencia

```bash
terraform -chdir=environments/dev plan -detailed-exitcode
```

**Resultado esperado**: código de salida `0` (sin cambios) si no se modificó nada desde el último
`apply` — confirma SC-005.

## 6. Simular detección de drift

Modifica manualmente una variable de un servicio desde el dashboard de Railway (solo para esta
prueba de validación, no como práctica habitual) y vuelve a ejecutar:

```bash
terraform -chdir=environments/dev plan -detailed-exitcode
```

**Resultado esperado**: código de salida `2`, y el `plan` describe la diferencia encontrada — esto
confirma que el mecanismo que el workflow de drift (cron) usa en producción detecta correctamente
los cambios manuales (FR-015). Revierte el cambio manual aplicando de nuevo la configuración
versionada para dejar el entorno `dev` consistente otra vez.
