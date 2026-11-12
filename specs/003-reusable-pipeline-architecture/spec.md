# Feature Specification: Arquitectura de Referencia — Una Sola Declaración de Recursos y Pipelines Reutilizables por Entorno

**Feature Branch**: `003-reusable-pipeline-architecture`

**Created**: 2026-11-11

**Status**: Draft

**Input**: User description: "Formalizar, como especificación de referencia, el patrón estructural observado en el proyecto tf-terranova (repositorio de Terraform + pipelines de otro proyecto, ya analizado y confirmado con el usuario) y exigir que mailysoft-infrastructure lo siga, tanto para Railway (proveedor activo hoy) como para Azure (proveedor que se incorporará más adelante), cada uno de forma independiente. Patrón: los recursos de un proveedor se declaran una sola vez, variando por entorno mediante configuración; la lógica de los pipelines de CI/CD se declara una sola vez y se reutiliza, cada entorno queda representado únicamente por su configuración; el plan revisado es el mismo que se aplica; la aprobación manual se controla por el mecanismo nativo de la plataforma de CI/CD, no por código del pipeline."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ejecutar o revertir un entorno sin arrastrar a los demás (Priority: P1)

Como responsable técnico de la plataforma, quiero que el pipeline de despliegue de un entorno pueda ejecutarse, reintentarse o revertirse sin que eso dispare ni dependa de la ejecución de los demás entornos, para poder actuar sobre dev, staging o production de forma aislada, igual que ya se exige para sus datos y su infraestructura.

**Why this priority**: Hoy el pipeline de aplicación encadena dev → staging → production dentro de una sola corrida. Es el obstáculo concreto y verificable para operar "un entorno a la vez", el mismo principio que ya se exigió para los proyectos de Railway en una fase anterior.

**Independent Test**: Puede probarse disparando un cambio que solo afecta a la configuración de un entorno y verificando que el pipeline resultante ejecuta y concluye sin iniciar, esperar ni dejar pendiente ninguna etapa de los demás entornos.

**Acceptance Scenarios**:

1. **Given** un cambio que solo modifica la configuración de dev, **When** se ejecuta el pipeline de despliegue, **Then** solo se ejecutan las etapas correspondientes a dev; staging y production no se ejecutan ni quedan pendientes.
2. **Given** que el despliegue de staging falla, **When** se reintenta su pipeline, **Then** el reintento ejecuta únicamente staging, sin re-ejecutar dev ni bloquearse en espera de production.

---

### User Story 2 - El plan revisado es el plan aplicado (Priority: P1)

Como responsable técnico de la plataforma, quiero que el cambio aplicado a un entorno sea exactamente el que fue mostrado y revisado antes de aprobarse, para que ninguna aprobación quede invalidada por un plan recalculado en el momento de aplicar.

**Why this priority**: Es la garantía central de que "revisar antes de aprobar" signifique algo. Si el apply puede calcular un plan distinto al revisado, la revisión previa no protege contra nada — y esta plataforma ya exige revisión explícita para cambios destructivos.

**Independent Test**: Puede probarse generando una previsualización para un entorno, modificando deliberadamente el estado real de ese entorno antes de aplicar, y verificando que el pipeline detiene la aplicación en lugar de aplicar silenciosamente un plan recalculado y distinto al revisado.

**Acceptance Scenarios**:

1. **Given** un plan ya revisado y aprobado para un entorno, **When** se ejecuta la etapa de aplicación, **Then** se aplica ese mismo plan, sin recalcular uno nuevo.
2. **Given** que el estado real de un entorno cambió después de generarse su plan revisado, **When** se intenta aplicar ese plan, **Then** el pipeline lo rechaza o lo señala explícitamente como inválido, en lugar de sustituirlo por un plan distinto sin nueva revisión.

---

### User Story 3 - Incorporar un entorno nuevo sin escribir lógica nueva (Priority: P2)

Como desarrollador de la plataforma, quiero que agregar un entorno nuevo (por ejemplo un cuarto entorno de pruebas) solo requiera archivos de configuración, para no arriesgarme a que ese entorno quede con una versión distinta de la lógica de infraestructura o de pipeline que los demás.

**Why this priority**: Ya es el comportamiento exigido para el root de Terraform. Esta historia extiende la misma garantía a los pipelines, que es la pieza que hoy no la garantiza de forma explícita.

**Independent Test**: Puede probarse agregando la configuración de un entorno nuevo (datos de Terraform y parámetros de pipeline) y verificando que ningún archivo de declaración de recursos ni de lógica de pipeline ya existente se modificó para lograrlo.

**Acceptance Scenarios**:

1. **Given** la lógica reutilizable de pipeline y el root de Terraform ya existentes, **When** se agrega un entorno nuevo únicamente con archivos de configuración, **Then** ese entorno queda operable (planeable y desplegable) sin cambios en los archivos de declaración de recursos ni en la lógica del pipeline.

---

### User Story 4 - El proveedor nuevo nace sin duplicación (Priority: P3)

Como responsable técnico de la plataforma, quiero que, cuando se incorpore Azure como proveedor de cómputo, su root de Terraform siga desde el inicio el mismo patrón de una sola declaración parametrizada por entorno, para no repetir el mismo problema que ya se corrigió en Railway ni acumular dos arquitecturas distintas dentro del mismo repositorio.

**Why this priority**: Previene trabajo futuro desechable. Su prioridad es menor porque Azure todavía no se construye en esta fase, pero fijar la regla ahora evita que se construya mal cuando llegue el momento.

**Independent Test**: Puede probarse revisando, en el momento en que se cree el primer archivo de recursos de Azure, que no existe una copia de ese archivo por entorno y que la variación entre entornos se resuelve con la misma mecánica de configuración ya usada para Railway.

**Acceptance Scenarios**:

1. **Given** que se inicia la construcción del root de Terraform de Azure, **When** se declaran sus recursos, **Then** se declaran una sola vez, variando por entorno mediante configuración, sin una copia de archivos por entorno.
2. **Given** los roots de Railway y de Azure ya existentes, **When** se opera cualquiera de los dos, **Then** ninguno requiere que el otro exista, esté inicializado ni tenga su proveedor configurado.

---

### Edge Cases

- ¿Qué ocurre si alguien intenta agregar un paso de pipeline que solo aplica a un entorno (p. ej., un paso especial solo para dev)? Debe rechazarse o quedar señalado como excepción que requiere justificación explícita; nunca aceptarse silenciosamente como parte de la configuración de ese entorno.
- ¿Qué ocurre si dos entornos necesitan ejecutarse en paralelo (p. ej. una corrección urgente en dev mientras production tiene un despliegue en curso)? Deben poder ejecutarse sin interferir entre sí, dado que esta especificación exige que cada entorno sea operable de forma independiente.
- ¿Qué ocurre si se agrega un entorno nuevo y su configuración resulta inválida (p. ej. falta un identificador de recurso)? Debe fallar en la etapa de validación del pipeline, igual que ya exige el Principio IV de la constitución para cualquier otra variable de configuración.
- ¿Qué ocurre con el plan ya aprobado de un entorno si, antes de que se alcance la etapa de aplicación, se fusiona otro cambio que también afecta a ese mismo entorno? El plan pendiente de aplicar debe invalidarse explícitamente y requerir una revisión nueva; nunca debe aplicarse junto con o por encima del cambio más reciente sin pasar de nuevo por revisión.
- ¿Qué ocurre si el proveedor nuevo (Azure) necesita una pieza de configuración que Railway no necesita, o viceversa? Cada root declara solo la configuración que su propio proveedor requiere; no se fuerza un esquema de configuración común entre proveedores que no lo necesitan.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST declarar los recursos de cada proveedor de infraestructura una sola vez por proveedor; MUST NOT existir más de una copia de la declaración de recursos de un mismo proveedor para distintos entornos.
- **FR-002**: El sistema MUST resolver toda variación entre entornos (dev, staging, production y cualquier entorno futuro) sobre la declaración de recursos de un proveedor mediante archivos de configuración, nunca mediante una rama de código ni una copia de archivos de recursos.
- **FR-003**: El sistema MUST mantener cada root de Terraform de un proveedor completamente independiente de los demás: ningún root MUST declarar el proveedor de otro ni depender de sus módulos; un proveedor MUST poder operarse aunque el root de otro proveedor no exista todavía.
- **FR-004**: Cuando se incorpore un proveedor de cómputo nuevo a la plataforma (p. ej. Azure), su root de Terraform MUST seguir, desde su primera versión, el mismo patrón de una sola declaración parametrizada por entorno exigido en FR-001/FR-002; MUST NOT iniciarse como una copia de archivos por entorno.
- **FR-005**: La base de datos de un entorno MUST aprovisionarse siempre en el mismo proveedor que el cómputo de ese entorno; el sistema MUST NOT dejar la base de datos de un entorno en un proveedor distinto al de sus servicios sin una advertencia y confirmación explícitas.
- **FR-006**: La lógica de cada etapa del pipeline de integración y despliegue continuo (instalación de herramientas, inicialización, validación, análisis estático, generación de plan, publicación del plan, aplicación) MUST definirse una sola vez y reutilizarse para todos los entornos; MUST NOT copiarse ni reescribirse para un entorno específico.
- **FR-007**: Cada entorno MUST quedar representado, de cara al pipeline, únicamente por su configuración (qué entorno es, qué credenciales o conexión usar, dónde está su estado remoto); esa configuración MUST NOT incluir pasos ni lógica adicional que no exista ya en la definición reutilizable del pipeline.
- **FR-008**: El sistema MUST permitir ejecutar, reintentar o revertir el pipeline de un entorno sin iniciar, esperar ni depender de la ejecución del pipeline de ningún otro entorno dentro de la misma corrida.
- **FR-009**: El plan generado y revisado para un cambio en un entorno MUST ser el mismo artefacto que se aplica para ese cambio; el sistema MUST NOT aplicar, en su lugar, un plan recalculado de forma independiente en el momento de aplicar.
- **FR-010**: Cuando el estado real de un entorno cambie después de generarse un plan ya revisado para él y antes de aplicarse, el sistema MUST rechazar la aplicación de ese plan o señalarlo explícitamente como inválido, y MUST requerir una revisión nueva antes de continuar.
- **FR-011**: La aprobación manual de cualquier entorno que la requiera MUST otorgarse mediante el mecanismo de aprobación nativo de la plataforma de CI/CD, nunca mediante un paso de código condicional escrito dentro de la lógica reutilizable del pipeline.
- **FR-012**: Agregar un entorno nuevo a la plataforma MUST lograrse añadiendo únicamente archivos de configuración (datos de Terraform y parámetros de pipeline), sin modificar la declaración de recursos de ningún proveedor ni la lógica reutilizable de ningún pipeline ya existente.

### Key Entities *(include if feature involves data)*

- **Root de Terraform por proveedor**: conjunto único de archivos de declaración de recursos para un proveedor (Railway, Azure, y cualquier proveedor futuro), nunca copiado por entorno.
- **Configuración de entorno**: los valores — nunca la lógica — propios de un entorno: identificadores de recursos ya creados, variables de servicios, ubicación de su estado remoto.
- **Lógica reutilizable de pipeline**: la definición única de las etapas de integración y despliegue continuo, parametrizada por entorno.
- **Configuración de pipeline por entorno**: la unidad mínima de datos que activa la lógica reutilizable para un entorno específico (qué entorno, qué credenciales, dónde está su estado).
- **Artefacto de plan**: el resultado de generar un plan para un entorno y un cambio dados; debe ser el mismo objeto que después se aplica, nunca un plan recalculado de forma independiente.

## Out of Scope

- Construir el root de Terraform de Azure en sí (recursos, módulos, variables concretas); queda como trabajo de una fase posterior. Esta especificación solo fija el patrón que ese trabajo futuro deberá seguir desde su primera versión.
- Cambiar el proveedor activo de cualquier entorno existente.
- Migrar de GitHub Actions a otra plataforma de CI/CD; esta especificación no reabre esa elección (Principio V), solo cómo se organiza la lógica de los pipelines dentro de ella.
- Añadir servicios o APIs nuevas a la plataforma.
- Rediseñar qué entornos requieren aprobación manual o bajo qué condiciones (ya definido en fases anteriores); esta especificación solo exige que ese mecanismo sea siempre nativo de la plataforma de CI/CD.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Añadir un entorno nuevo requiere únicamente archivos de configuración nuevos, sin añadir ni modificar ninguna declaración de recursos ni ninguna lógica de pipeline ya existente.
- **SC-002**: Desplegar, reintentar o revertir un entorno no requiere ejecutar ni esperar la ejecución de ningún otro entorno dentro de la misma corrida de pipeline.
- **SC-003**: El 100% de los cambios aplicados a un entorno corresponden exactamente al plan que fue revisado para ese cambio; ninguna aplicación auditada recalcula y aplica un plan distinto al revisado sin pasar de nuevo por revisión.
- **SC-004**: Cuando se incorpore un proveedor nuevo a un entorno, su primera versión ya cumple el patrón de una sola declaración de recursos parametrizada por entorno, sin pasar primero por una copia por entorno.
- **SC-005**: El 100% de las aprobaciones manuales registradas ocurren mediante el mecanismo nativo de aprobación de la plataforma de CI/CD, nunca mediante un paso de código condicional dentro del propio pipeline.

## Assumptions

- Esta especificación no cambia el proveedor activo de ningún entorno existente: Railway sigue siendo el proveedor en uso hoy; Azure es un proveedor que se incorporará más adelante, no una exigencia simultánea.
- El root de Terraform de Railway (`environments/`) ya satisface FR-001/FR-002 tras una corrección reciente; los requisitos de esta especificación sobre roots de Terraform formalizan esa decisión como una regla permanente y la extienden, por anticipado, al futuro root de Azure.
- "Lógica de pipeline" se refiere a la secuencia de etapas (instalar herramientas, inicializar, validar, analizar, planear, publicar el plan, aplicar) y su implementación; "configuración" se refiere a los valores que cambian por entorno (nombre del entorno, referencia a credenciales, ubicación del estado remoto, archivos de variables). Esta especificación no exige una disposición de archivos concreta (p. ej. no exige un archivo de pipeline por entorno en la raíz del repositorio): exige el resultado — ninguna lógica de etapa copiada ni reescrita por entorno, y cada entorno operable de forma independiente de los demás.
- GitHub Actions sigue siendo la plataforma de CI/CD (Principio V); esta especificación no reabre esa elección.
- La base de datos de cada entorno sigue siempre al proveedor de cómputo de ese entorno, consistente con la fase anterior (002-single-provider-deployment); esta especificación no modifica esa regla, la reafirma como condición permanente.
