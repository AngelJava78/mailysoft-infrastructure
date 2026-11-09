# ADR 0003: Postgres administrado en Railway como `railway_service` + volumen, sin verificar

**Estado**: Aceptado (con riesgo documentado)
**Fecha**: 2026-11-08
**Contexto**: [specs/002-single-provider-deployment](../../specs/002-single-provider-deployment/)

## Contexto

Cuando un entorno elige Railway como proveedor único (FR-001), necesita una base de datos
propia ahí — la que ya existe en Azure (`mailysoft-db`) permanece protegida contra
recreación o destrucción en cualquier escenario (Principio II; FR-012). No existe, hasta esta
fase, ningún módulo que aprovisione una base de datos *en* Railway.

Durante la investigación (ver
[research.md](../../specs/002-single-provider-deployment/research.md) sección 3) se
encontró que:

- Railway publica una imagen oficial de Postgres con SSL
  (`ghcr.io/railwayapp-templates/postgres-ssl`, confirmada contra su documentación y su
  repositorio público).
- El provider comunitario de Terraform (`terraform-community-providers/railway`, el mismo
  que ya se acepta como riesgo en
  [ADR 0001](./0001-railway-terraform-community-provider.md)) parece soportar la creación de
  un recurso de volumen persistente, pero la comunidad de Railway ha reportado al menos un
  error 504 al crearlo con ese provider — no se confirmó el nombre exacto del recurso ni de
  sus atributos contra el registro de Terraform.
- Tampoco se confirmó que `railway_service` acepte desplegarse desde una imagen de
  contenedor (`source_image`) en vez de un repositorio (`source_repo`, el único atributo
  usado hasta ahora en `modules/service/railway`).

## Decisión

Modelar la base de datos administrada de Railway (`modules/database/railway-managed`) como
un `railway_service` más desde esa imagen, con un `railway_volume` adjunto para persistencia
y una contraseña generada con `random_password` (nunca leída de un secreto externo, porque al
crearse por primera vez no existe ninguno). Se acepta el mismo tipo de riesgo operativo ya
aceptado en el ADR 0001 para este mismo provider, con la misma mitigación: confirmar contra
`registry.terraform.io` antes del primer `apply` real (documentado también en
`modules/database/railway-managed/README.md`).

## Alternativas consideradas

- **Plantilla de un clic de Postgres de Railway, fuera de Terraform**: rechazada como
  decisión por defecto porque viola el Principio III (Terraform como única fuente de
  verdad); queda documentada como alternativa a reconsiderar *solo si*, al verificar el
  riesgo de arriba, el recurso de volumen o el despliegue desde imagen no existen en el
  provider — nunca como un recurso creado manualmente sin dejar rastro.
- **Usar siempre la base de datos de Azure aunque el entorno elija Railway**: rechazada
  porque contradice el objetivo central de esta fase (FR-001) y mezclaría silenciosamente
  proveedores sin pasar por la advertencia explícita de FR-014.

## Consecuencias

- `modules/database/railway-managed` declara recursos de escritura (a diferencia de
  `modules/database/azure-existing`, que solo lee) — aislado por entorno, sin ninguna
  referencia a los recursos de Azure (FR-012).
- El riesgo de este ADR se revisa junto con el del ADR 0001 antes de cualquier `apply` real
  contra un entorno que elija Railway con una base de datos nueva.
