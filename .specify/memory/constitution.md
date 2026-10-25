<!--
Sync Impact Report
Versión: plantilla sin ratificar → 1.0.0 (adopción inicial)
Principios modificados: N/A (primera ratificación; se definen 8 principios nuevos)
Secciones añadidas:
  - Principio I. Propósito y Alcance
  - Principio II. Multi-Nube Configurable con Prioridad Definida
  - Principio III. Terraform como Única Fuente de Verdad
  - Principio IV. Configuración sobre Código
  - Principio V. Pipelines CI/CD como Único Camino de Despliegue
  - Principio VI. Seguridad y Gestión de Secretos
  - Principio VII. Convenciones de Nomenclatura y Etiquetado
  - Principio VIII. Calidad y Documentación
  - Gobernanza (procedimiento de enmienda, política de versionado, revisión de cumplimiento)
Secciones eliminadas: [SECTION_2_NAME]/[SECTION_3_NAME] genéricas de la plantilla (sin contenido propio;
  todo el contenido aportado por el usuario encaja en los 8 principios y en Gobernanza)
Plantillas dependientes: no se modifican en este comando (se leen en tiempo de ejecución); revisar en el
  próximo /speckit-plan o /speckit-tasks que referencien explícitamente estos principios al verificar cumplimiento
TODOs diferidos:
  - TODO(RATIFICATION_DATE): se usa la fecha de creación de este documento (2026-10-24) como fecha de
    ratificación inicial a falta de una fecha histórica distinta proporcionada por el usuario
-->

# Constitución de mailysoft-infrastructure

## Core Principles

### I. Propósito y Alcance
Este repositorio contiene ÚNICAMENTE infraestructura como código (IaC) y pipelines de despliegue.
Código de aplicación NUNCA se almacena, construye ni compila aquí.

- Gestiona exclusivamente los recursos de los siguientes servicios de la plataforma MailySoft:
  API de usuarios (`mailysoft-usuarios-api`), API de pacientes (`mailysoft-pacientes-api`), API de
  sistema (`mailysoft-sistema-api`), backoffice (`mailysoft-backoffice`), frontend
  (`mailysoft-web`), base de datos PostgreSQL (`mailysoft-db`), y cualquier API futura que se
  incorpore a la plataforma.
- Los microservicios están escritos en Python y viven en repositorios independientes. Este
  repositorio los despliega; NUNCA construye, compila, prueba unitariamente ni modifica su código
  fuente.
- Cualquier cambio propuesto que requiera tocar código de aplicación DEBE rechazarse en este
  repositorio y redirigirse al repositorio del servicio correspondiente.

**Rationale**: separar infraestructura de aplicación acota el radio de impacto de cada repositorio,
permite que equipos de aplicación y de plataforma avancen de forma independiente, y evita que un
cambio de infraestructura se mezcle involuntariamente con lógica de negocio.

### II. Multi-Nube Configurable con Prioridad Definida
La plataforma soporta múltiples proveedores de nube bajo un orden de prioridad fijo y una
implementación por fases.

- Proveedores soportados, en este orden de prioridad: (1) Railway, (2) Azure, (3) AWS.
- Railway es el proveedor por defecto para cualquier servicio o entorno que no especifique otro
  explícitamente.
- Azure y AWS DEBEN poder activarse mediante configuración (variables y archivos de entorno),
  NUNCA mediante reescritura del código de los módulos Terraform.
- El proveedor de destino DEBE ser seleccionable por entorno y, cuando el diseño del módulo lo
  permita, por servicio individual (ej.: APIs en Railway y base de datos en Azure de forma
  simultánea).
- La base de datos PostgreSQL que ya existe en Azure (`mailysoft-db`) DEBE referenciarse como
  recurso de datos existente o importarse explícitamente (`terraform import`). Está PROHIBIDO
  definirla de forma que un `apply` pueda recrearla o destruirla accidentalmente.
- El soporte multi-nube se implementa por fases: Fase 1 Railway completo → Fase 2 Azure → Fase 3
  AWS. Ninguna fase posterior puede romper, cambiar el contrato de, o degradar una fase ya
  entregada.

**Rationale**: fija una ruta de adopción incremental y de bajo riesgo, evita el vendor lock-in a
largo plazo y protege explícitamente un recurso de producción crítico (la base de datos de
pacientes) frente a recreación accidental.

### III. Terraform como Única Fuente de Verdad
Toda la infraestructura se define, se audita y se cambia a través de Terraform.

- Está PROHIBIDO crear o modificar recursos manualmente desde las consolas web de Railway, Azure
  o AWS, salvo en el acto de importación inicial de un recurso preexistente, documentado como tal.
- Arquitectura modular obligatoria: módulos reutilizables organizados por tipo de recurso
  (servicio/compute, base de datos, red, dominio, variables), cada uno con una implementación
  concreta por proveedor detrás de una interfaz común (misma firma de entradas y salidas).
- Las versiones de Terraform y de cada provider DEBEN fijarse de forma exacta (pinned), nunca con
  rangos abiertos, para garantizar ejecuciones reproducibles.
- El estado (state) DEBE almacenarse en un backend remoto con bloqueo (locking) y cifrado en
  reposo habilitados, y DEBE segregarse por entorno: dev, staging y production nunca comparten
  state.
- Agregar una nueva API a la plataforma DEBE lograrse añadiendo únicamente configuración sobre los
  módulos existentes; está PROHIBIDO duplicar código de módulo para dar de alta un nuevo servicio.

**Rationale**: una única fuente de verdad elimina el drift entre lo declarado y lo real; la
interfaz común por tipo de recurso es lo que hace posible el cambio de proveedor por
configuración exigido en el Principio II.

### IV. Configuración sobre Código
Todo lo que varía por entorno o despliegue es dato de configuración, no lógica de módulo.

- Proveedor, región, tamaños/SKU, número de réplicas, dominios, servicios habilitados y variables
  de entorno de los servicios DEBEN vivir en archivos de configuración por entorno, nunca
  hardcodeados en el código de los módulos Terraform.
- Entornos mínimos soportados: dev, staging y production, cada uno con su propia configuración
  independiente y su propio estado remoto.
- Cada variable de configuración DEBE tener un valor por defecto seguro y documentado, y DEBE
  validarse (tipo, rango o enumeración) antes de aplicarse; un valor inválido DEBE fallar en la
  etapa de validación, nunca durante el `apply`.

**Rationale**: mantiene el código de los módulos estable y agnóstico de entorno/proveedor,
convirtiendo las diferencias entre dev/staging/production en datos auditables en lugar de
bifurcaciones de código.

### V. Pipelines CI/CD como Único Camino de Despliegue
Ningún despliegue a staging o production ocurre fuera de un pipeline auditado.

- Todo despliegue a staging o production se ejecuta EXCLUSIVAMENTE mediante pipelines de GitHub
  Actions. Ejecutar `terraform apply` contra staging o production desde una máquina local está
  PROHIBIDO.
- El pipeline DEBE ejecutar, en este orden, las etapas: formato → validación → lint → análisis de
  seguridad → plan → revisión → apply.
- En pull requests el pipeline DEBE ejecutar únicamente `plan` (nunca `apply`), y su resultado DEBE
  publicarse de forma visible para revisión humana antes de fusionar.
- El `apply` sobre production REQUIERE aprobación manual explícita antes de ejecutarse.
- El pipeline recibe entorno y proveedor como parámetros de entrada, y DEBE resolver sus valores
  por defecto respetando el orden de prioridad Railway → Azure → AWS del Principio II.
- DEBE existir un mecanismo de detección de drift entre el estado real de la infraestructura y el
  Terraform state, y una estrategia de rollback documentada y accionable.

**Rationale**: centralizar el despliegue en pipelines hace que cada cambio a infraestructura
compartida sea revisable, reproducible y auditable, y el gate manual en production acota el
impacto de errores humanos.

### VI. Seguridad y Gestión de Secretos
Los datos de pacientes y las credenciales de la plataforma se tratan como sensibles por defecto.

- Ningún secreto, token o credencial se almacena en el repositorio (código o configuración
  versionada) ni en el Terraform state en texto plano.
- Los secretos se gestionan mediante GitHub Secrets/Environments y el gestor nativo de secretos de
  cada nube; el repositorio solo referencia su ubicación, nunca su valor.
- Se prefiere autenticación sin credenciales de larga duración (OIDC) frente a claves estáticas, en
  cualquier proveedor que lo soporte.
- Se aplica el principio de mínimo privilegio en todos los roles e identidades usados por pipelines
  y módulos.
- Los datos de pacientes son sensibles: toda ruta que los toca (`mailysoft-pacientes-api`,
  `mailysoft-db`) DEBE cifrarse en tránsito y en reposo, y el acceso a la base de datos DEBE
  restringirse mediante reglas de red/firewall e identidades con permisos mínimos necesarios.

**Rationale**: la plataforma maneja datos de salud; un secreto filtrado o un acceso de base de
datos sobre-privilegiado tiene consecuencias legales y de confianza desproporcionadas frente a
otros tipos de fallo.

### VII. Convenciones de Nomenclatura y Etiquetado
La consistencia de nombres y etiquetas es lo que hace posible automatizar costos, propiedad y
políticas a través de proveedores.

- Todos los nombres de recursos usan minúsculas con el formato `mailysoft-<servicio>-<entorno>`.
- Todo recurso gestionado por Terraform DEBE llevar las etiquetas obligatorias: `proyecto`,
  `servicio`, `entorno`, `propietario`, `gestionado-por=terraform`.
- La documentación del repositorio se escribe en español. Los identificadores técnicos (variables,
  recursos, módulos) se mantienen consistentes en un único idioma dentro de todo el repositorio.

**Rationale**: nombres y etiquetas uniformes permiten trazar propiedad y costo por servicio/entorno
y habilitan políticas automatizadas (presupuesto, acceso, limpieza) sin depender de convenciones
ad hoc por proveedor.

### VIII. Calidad y Documentación
Un módulo o decisión sin documentar es deuda técnica inmediata en un repositorio multi-proveedor.

- Cada módulo Terraform DEBE documentar sus entradas (variables), salidas (outputs) y al menos un
  ejemplo de uso.
- El README raíz DEBE describir los pasos concretos para añadir un nuevo servicio, un nuevo entorno
  y un nuevo proveedor.
- Las decisiones de arquitectura relevantes (ej.: elegir un proveedor para un servicio, estrategia
  de importación de la base de datos existente) se registran como Architecture Decision Records
  (ADR).
- Todo cambio destructivo (reemplazo o eliminación de recursos) detectado en un `terraform plan`
  DEBE señalarse explícitamente durante la revisión y requiere aprobación explícita antes de
  aplicarse, incluso en entornos distintos de production.

**Rationale**: en un repositorio modular y multi-nube, la documentación de contratos de módulo y
las ADR son lo único que preserva el "por qué" de una decisión una vez que el código cambia.

## Governance

Esta constitución prevalece sobre cualquier especificación, plan o tarea de este repositorio. Toda
especificación (`spec.md`), plan (`plan.md`) o checklist generado por Spec Kit DEBE verificar
explícitamente su cumplimiento con los principios anteriores antes de aprobarse.

- **Procedimiento de enmienda**: las modificaciones a esta constitución se realizan exclusivamente
  mediante pull request. El PR DEBE incluir el nuevo número de versión, la justificación del cambio
  y, si aplica, el impacto sobre plantillas o documentos dependientes.
- **Política de versionado**: se usa versionado semántico (`MAJOR.MINOR.PATCH`):
  - MAJOR: eliminación o redefinición incompatible de un principio existente.
  - MINOR: adición de un nuevo principio o ampliación material de una guía existente.
  - PATCH: aclaraciones de redacción, correcciones y refinamientos no semánticos.
- **Revisión de cumplimiento**: toda revisión de código o de infraestructura que toque este
  repositorio DEBE confirmar que el cambio no viola ninguno de los principios anteriores. Cualquier
  excepción DEBE justificarse por escrito en el propio PR y, si es recurrente, DEBE motivar una
  enmienda a esta constitución en lugar de una excepción permanente no documentada.

**Version**: 1.0.0 | **Ratified**: 2026-10-24 | **Last Amended**: 2026-10-24
