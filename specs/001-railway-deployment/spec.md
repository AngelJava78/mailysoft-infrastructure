# Feature Specification: Despliegue Automatizado de MailySoft en Railway (Fase 1 Multi-Nube)

**Feature Branch**: `001-railway-deployment`

**Created**: 2026-10-24

**Status**: Draft

**Input**: User description: "Necesito poder desplegar y gestionar de forma automatizada y repetible toda la infraestructura de la plataforma MailySoft en Railway, como primera fase de una estrategia multi-nube (Railway → Azure → AWS), de modo que el equipo deje de crear o modificar recursos manualmente. CONTEXTO: MailySoft es una plataforma de gestión de pacientes compuesta por microservicios en Python que viven en repositorios independientes: API de usuarios (mailysoft-usuarios-api), API de pacientes (mailysoft-pacientes-api), API de sistema (mailysoft-sistema-api), Backoffice (mailysoft-backoffice), Frontend web (mailysoft-web, aún no creado), Base de datos PostgreSQL (mailysoft-db, actualmente en Azure). Se añadirán más APIs en el futuro. Los datos de pacientes son sensibles. Aunque la base de datos está desplegada en Azure, también se debe poder desplegar en Railway, Azure o AWS. ACTORES: Desarrollador, Revisor/Responsable técnico, Pipeline de despliegue. Ver historias de usuario, requisitos funcionales, fuera de alcance y criterios de éxito detallados en la conversación original."

## Clarifications

### Session 2026-10-24

- Q: ¿Qué marco regulatorio de protección de datos de salud debe cumplir esta plataforma? → A: Sin marco regulatorio externo formal aún (ni tipo HIPAA ni RGPD específico); solo las políticas internas de la empresa y los controles ya definidos en la constitución del repositorio (cifrado en tránsito/reposo y mínimo privilegio).
- Q: ¿Existe un requisito de región/ubicación geográfica para los servicios desplegados en Railway, dado que deben conectarse a la base de datos de Azure? → A: Los servicios deben desplegarse en la región de Railway más cercana a la región donde reside la base de datos de Azure, de entre las regiones que soporten los servicios requeridos; la región concreta se determina como configuración por entorno, no se fija en esta especificación.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Desplegar toda la plataforma en Railway sin pasos manuales (Priority: P1)

Como desarrollador, quiero desplegar todos los servicios de MailySoft en Railway en un entorno, para tener la plataforma funcionando sin pasos manuales en ninguna consola.

**Why this priority**: Es el valor central de esta fase: sin esto, el equipo sigue dependiendo de la creación manual de recursos, que es precisamente lo que se busca eliminar. Sin esta historia no hay MVP.

**Independent Test**: Puede probarse ejecutando el pipeline de despliegue contra un entorno vacío y verificando que, al finalizar, los servicios configurados (APIs, backoffice y la referencia a la base de datos) quedan operativos en Railway sin que nadie haya tocado la consola web de Railway.

**Acceptance Scenarios**:

1. **Given** un entorno sin recursos previos en Railway y una configuración completa para ese entorno, **When** se ejecuta el pipeline de despliegue y se aprueba el cambio, **Then** todos los servicios habilitados quedan desplegados y accesibles según su configuración de dominio, sin intervención manual en la consola de Railway.
2. **Given** un entorno ya desplegado, **When** se vuelve a ejecutar el pipeline sin cambios en la configuración, **Then** no se reporta ningún cambio adicional sobre la infraestructura (resultado idempotente).

---

### User Story 2 - Previsualizar cambios antes de aplicarlos (Priority: P1)

Como desarrollador, quiero ver qué cambios se aplicarán antes de que ocurran, para evitar sorpresas o destrucción accidental de recursos.

**Why this priority**: Sin previsualización, cualquier error de configuración puede destruir o alterar recursos en producción sin posibilidad de reacción. Es un requisito de seguridad operativa, no una mejora opcional.

**Independent Test**: Puede probarse proponiendo un cambio de configuración (por ejemplo, modificar una variable de entorno de un servicio) y verificando que el sistema genera una previsualización legible de ese cambio antes de que exista cualquier posibilidad de aplicarlo.

**Acceptance Scenarios**:

1. **Given** un cambio propuesto en la configuración de un servicio o entorno, **When** se inicia el proceso de despliegue, **Then** el sistema genera automáticamente una previsualización de los cambios que se aplicarían, antes de aplicar nada.
2. **Given** una previsualización generada, **When** el cambio incluye la eliminación o el reemplazo de un recurso existente, **Then** ese cambio se destaca explícitamente en la previsualización como destructivo.

---

### User Story 3 - Exigir aprobación para desplegar a producción (Priority: P1)

Como responsable técnico, quiero que los despliegues a producción requieran mi aprobación, para proteger los datos de pacientes.

**Why this priority**: Los datos de pacientes son sensibles; un cambio no revisado en producción es el escenario de mayor riesgo que esta fase debe prevenir. Junto con las dos historias anteriores, completa el MVP de un flujo de cambio seguro.

**Independent Test**: Puede probarse proponiendo un cambio hacia el entorno de producción y verificando que el pipeline se detiene en un punto de aprobación explícita, y que el cambio no se aplica hasta que un responsable técnico lo apruebe.

**Acceptance Scenarios**:

1. **Given** una previsualización de cambios para el entorno de producción, **When** el cambio aún no ha sido aprobado por un responsable técnico, **Then** el sistema no aplica el cambio.
2. **Given** una previsualización de cambios para el entorno de producción, **When** un responsable técnico aprueba explícitamente el cambio, **Then** el sistema procede a aplicarlo.

---

### User Story 4 - Mantener entornos separados (Priority: P2)

Como desarrollador, quiero tener entornos separados (dev, staging, production), para probar cambios sin afectar a producción.

**Why this priority**: Habilita la práctica segura de probar antes de promover, pero la plataforma ya puede operar con un solo entorno mientras se valida el flujo de las historias P1.

**Independent Test**: Puede probarse desplegando el mismo conjunto de servicios con configuraciones distintas en dev y en staging, y verificando que un cambio aplicado en dev no modifica ningún recurso de staging ni de production.

**Acceptance Scenarios**:

1. **Given** configuraciones independientes para dev, staging y production, **When** se aplica un cambio en dev, **Then** ni staging ni production reportan ningún cambio en su infraestructura.
2. **Given** los tres entornos desplegados, **When** se inspecciona cada uno, **Then** cada entorno mantiene su propio conjunto de servicios habilitados y su propia configuración, sin mezclarse entre sí.

---

### User Story 5 - Conectar servicios en Railway a la base de datos existente en Azure (Priority: P2)

Como desarrollador, quiero que los servicios de Railway puedan conectarse a la base de datos existente en Azure, sin recrearla ni migrarla.

**Why this priority**: La plataforma no es funcional para los usuarios finales si las APIs no pueden leer ni escribir datos de pacientes, pero depende de que las historias P1 (despliegue base) ya funcionen.

**Independent Test**: Puede probarse desplegando una API que requiere base de datos y verificando que se conecta exitosamente a la base de datos de Azure usando únicamente datos de conexión referenciados por configuración, sin que el pipeline intente crear, modificar o destruir esa base de datos.

**Acceptance Scenarios**:

1. **Given** una API desplegada en Railway con la base de datos de Azure referenciada como recurso externo, **When** la API arranca, **Then** se conecta correctamente a esa base de datos usando los datos de conexión provistos de forma segura.
2. **Given** un ciclo completo de despliegue o re-despliegue, **When** se ejecuta el pipeline, **Then** la base de datos de Azure no se crea, no se recrea y no se destruye en ningún momento.

---

### User Story 6 - Añadir una nueva API solo con configuración (Priority: P2)

Como desarrollador, quiero añadir una nueva API solo agregando su configuración, sin duplicar definiciones existentes.

**Why this priority**: MailySoft seguirá creciendo con nuevas APIs; sin esta capacidad, cada nueva API implicaría reescribir trabajo ya hecho, lo que contradice el propósito de esta fase, aunque no bloquea el valor ya entregado por las historias P1.

**Independent Test**: Puede probarse agregando la configuración de una API ficticia nueva (sin tocar la definición de las APIs ya existentes) y verificando que, tras la aprobación, queda desplegada igual que las demás.

**Acceptance Scenarios**:

1. **Given** una nueva API aún no representada en la plataforma, **When** se agrega únicamente su bloque de configuración (origen de código, variables de entorno, dominio, recursos), **Then** la nueva API queda desplegada tras la aprobación, sin haber modificado la configuración de ninguna API existente.
2. **Given** la adición de esa nueva API, **When** se revisa el cambio propuesto, **Then** la previsualización no muestra ninguna modificación sobre los servicios ya existentes.

---

### User Story 7 - Elegir el proveedor de destino por configuración (Priority: P3)

Como responsable técnico, quiero elegir por configuración el proveedor de destino de cada servicio y entorno, para poder activar Azure o AWS en fases posteriores sin rehacer el trabajo.

**Why this priority**: Prepara el camino para las fases 2 y 3 de la estrategia multi-nube, pero en esta fase el valor inmediato es menor porque solo Railway está operativo.

**Independent Test**: Puede probarse cambiando, en la configuración de un servicio o entorno, el proveedor declarado a "Azure" o "AWS" y verificando que el sistema responde con un mensaje explícito de "proveedor no disponible aún", en lugar de intentar un despliegue parcial o fallar de forma inesperada.

**Acceptance Scenarios**:

1. **Given** la configuración de un servicio con proveedor "Railway", **When** se despliega, **Then** el despliegue procede normalmente contra Railway.
2. **Given** la configuración de un servicio o entorno con proveedor "Azure" o "AWS", **When** se intenta desplegar en esta fase, **Then** el sistema rechaza la operación con un mensaje claro de que ese proveedor aún no está disponible, sin aplicar ningún cambio parcial.

---

### User Story 8 - Detectar diferencias entre la infraestructura real y la definida (Priority: P3)

Como responsable técnico, quiero detectar cuándo la infraestructura real difiere de la definida, para corregir cambios manuales.

**Why this priority**: Es una red de seguridad contra el incumplimiento de "Terraform como única fuente de verdad", valiosa pero no bloqueante para que el resto de las historias entreguen valor.

**Independent Test**: Puede probarse modificando manualmente un recurso directamente en Railway (fuera del flujo del pipeline) y verificando que una ejecución de detección de drift reporta esa diferencia sin corregirla automáticamente de forma destructiva.

**Acceptance Scenarios**:

1. **Given** un recurso cuya configuración real en Railway difiere de lo definido en la configuración versionada, **When** se ejecuta la detección de drift, **Then** el sistema reporta explícitamente esa diferencia, identificando el recurso afectado.
2. **Given** ninguna diferencia entre lo real y lo definido, **When** se ejecuta la detección de drift, **Then** el sistema reporta que no hay drift.

---

### Edge Cases

- ¿Qué ocurre si se configura un servicio o la base de datos con proveedor "Azure" o "AWS" en esta fase? El sistema debe rechazar la operación con un mensaje explícito de "no disponible aún", sin aplicar cambios parciales.
- ¿Qué ocurre si falta una variable de configuración obligatoria o tiene un valor inválido para un servicio o entorno? La validación debe fallar antes de generar la previsualización, señalando qué valor es inválido y por qué.
- ¿Qué ocurre si una previsualización incluye la eliminación o el reemplazo de un recurso? Debe destacarse explícitamente como cambio destructivo y requerir aprobación explícita antes de poder aplicarse, en cualquier entorno.
- ¿Qué ocurre si las credenciales de conexión a la base de datos de Azure son inválidas o han cambiado? El servicio afectado debe fallar su conexión de forma clara y diagnosticable, sin que la credencial o el error expongan el valor del secreto en ningún registro.
- ¿Qué ocurre si se aplica dos veces la misma configuración sin cambios entre ambas ejecuciones? La segunda ejecución no debe reportar ni producir ningún cambio adicional sobre la infraestructura.
- ¿Qué ocurre si se deshabilita en la configuración un servicio que estaba habilitado en un entorno? El sistema debe proponerlo como cambio (incluyendo, si corresponde, la eliminación de sus recursos), destacándolo como destructivo y requiriendo aprobación.
- ¿Qué ocurre si se detecta drift entre la infraestructura real y la definida? El sistema debe reportarlo para revisión humana, sin aplicar automáticamente una corrección destructiva.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST permitir desplegar en Railway cada servicio de MailySoft (mailysoft-usuarios-api, mailysoft-pacientes-api, mailysoft-sistema-api, mailysoft-backoffice, mailysoft-web, y futuras APIs) con su propia configuración de: origen del código, variables de entorno, tipo de dominio (público o privado) y recursos asignados.
- **FR-002**: El sistema MUST permitir habilitar o deshabilitar cada servicio de forma independiente, por entorno, sin afectar a los demás servicios de ese mismo entorno.
- **FR-003**: El sistema MUST soportar al menos tres entornos independientes (dev, staging, production), cada uno con su propia configuración y su propio estado de infraestructura, de forma que un cambio en un entorno no modifique otro.
- **FR-004**: El sistema MUST permitir seleccionar, mediante configuración, el proveedor de destino (Railway, Azure o AWS) por entorno y, cuando el servicio lo permita, de forma individual por servicio.
- **FR-005**: En esta fase, el sistema MUST operar únicamente contra Railway como proveedor activo; si la configuración de un servicio o entorno selecciona Azure o AWS, el sistema MUST rechazar la operación antes de aplicar ningún cambio, mostrando un mensaje explícito de que ese proveedor aún no está disponible.
- **FR-006**: El sistema MUST tratar la base de datos PostgreSQL existente en Azure (mailysoft-db) como un recurso externo ya existente: MUST consumir únicamente sus datos de conexión y MUST NOT crearla, recrearla ni destruirla desde esta fase.
- **FR-007**: Los servicios desplegados en Railway que requieran base de datos MUST poder conectarse correctamente a la base de datos de Azure usando los datos de conexión declarados en la configuración, sin pasos de configuración manual adicionales.
- **FR-008**: El sistema MUST generar automáticamente una previsualización revisable de cualquier cambio propuesto, para cualquier entorno, antes de que ese cambio pueda aplicarse.
- **FR-009**: El sistema MUST impedir que un cambio se aplique sobre el entorno de producción sin una aprobación manual explícita de un responsable técnico, posterior a la revisión de la previsualización.
- **FR-010**: El sistema MUST identificar y destacar explícitamente, dentro de la previsualización, cualquier cambio que elimine o reemplace un recurso existente, y MUST requerir aprobación explícita antes de aplicar ese cambio en cualquier entorno.
- **FR-011**: El sistema MUST evitar que cualquier secreto (credenciales de base de datos, tokens) aparezca en texto plano en el repositorio, en los registros del pipeline o en el contenido de la previsualización.
- **FR-012**: Añadir una nueva API a la plataforma MUST requerir únicamente agregar su configuración, sin duplicar ni modificar la definición de los servicios ya existentes, y MUST quedar desplegada automáticamente tras su aprobación.
- **FR-013**: El sistema MUST ofrecer un procedimiento documentado para volver a la última versión estable conocida de la infraestructura desplegada.
- **FR-014**: El sistema MUST ofrecer documentación de los pasos necesarios para añadir un nuevo servicio, añadir un nuevo entorno y, en una fase futura, añadir un nuevo proveedor.
- **FR-015**: El sistema MUST detectar cuándo la infraestructura real en Railway difiere de la configuración definida (drift) y MUST reportar esa diferencia para revisión humana, sin aplicar una corrección automática destructiva.
- **FR-016**: Aplicar la misma configuración más de una vez sin cambios intermedios MUST NOT producir ninguna modificación adicional sobre la infraestructura ya desplegada (idempotencia).
- **FR-017**: El sistema MUST desplegar los servicios en la región de Railway más cercana a la región donde reside la base de datos de Azure, de entre las regiones que soporten los servicios requeridos, para minimizar la latencia de conexión a los datos de pacientes.

### Key Entities *(include if feature involves data)*

- **Servicio**: unidad desplegable de la plataforma (API, backoffice o frontend), identificada por nombre; incluye origen del código, variables de entorno, tipo de dominio y recursos asignados; puede habilitarse o deshabilitarse de forma independiente por entorno.
- **Entorno**: contexto de despliegue aislado (dev, staging o production) con su propia configuración y su propio estado de infraestructura.
- **Proveedor de destino**: la nube donde se despliega un servicio o la base de datos (Railway, Azure o AWS), seleccionable por configuración a nivel de entorno y, cuando aplica, a nivel de servicio.
- **Recurso de base de datos externo**: la base de datos PostgreSQL ya existente en Azure (mailysoft-db), referenciada mediante sus datos de conexión, nunca creada ni destruida desde esta fase.
- **Previsualización de cambios**: representación revisable de los cambios que se aplicarían a un entorno, generada antes de cualquier aplicación, que señala explícitamente las eliminaciones o reemplazos de recursos.
- **Secreto**: credencial o token (por ejemplo, credenciales de conexión a base de datos) que debe permanecer fuera del repositorio, de los registros del pipeline y de la previsualización.

## Out of Scope

- La construcción, prueba o empaquetado del código de los microservicios de MailySoft (eso ocurre en sus propios repositorios).
- El despliegue real de servicios en Azure o AWS; esta especificación cubre únicamente la fase en que Railway es el proveedor operativo. Azure y AWS se cubrirán en especificaciones de fases posteriores.
- La migración de la base de datos PostgreSQL de Azure a cualquier otro proveedor.
- La creación del proyecto de código del frontend (mailysoft-web); esta especificación solo cubre que la plataforma de despliegue esté lista para incorporarlo cuando exista.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un entorno completo de MailySoft puede crearse desde cero en Railway sin ejecutar ningún paso manual en una consola web.
- **SC-002**: Añadir una nueva API a la plataforma requiere únicamente cambios de configuración y queda desplegada en el entorno correspondiente tras su aprobación.
- **SC-003**: El 100% de los cambios aplicados en el entorno de producción han pasado previamente por una previsualización revisada y una aprobación explícita.
- **SC-004**: Ningún secreto (credencial o token) resulta visible en el repositorio ni en los registros de ejecución del pipeline, en el 100% de las ejecuciones auditadas.
- **SC-005**: Aplicar la misma configuración de un entorno dos veces consecutivas, sin cambios entre ambas ejecuciones, no produce ninguna modificación adicional sobre la infraestructura.
- **SC-006**: El 100% de los servicios desplegados en Railway que requieren acceso a datos de pacientes se conectan correctamente a la base de datos existente en Azure.

## Assumptions

- Antes de iniciar el despliegue, el equipo ya cuenta con una cuenta/organización de Railway y con las credenciales de conexión a la base de datos de Azure disponibles para registrarlas como secretos en el pipeline.
- Cada entorno (dev, staging, production) se modela como un espacio de despliegue propio dentro de Railway, de forma que los recursos de un entorno no se mezclan con los de otro.
- La aprobación manual de responsable técnico para producción se realiza a través del mecanismo de revisión y protección de entornos ya disponible en la plataforma de CI/CD del equipo, sin requerir una herramienta externa adicional.
- La detección de drift en esta fase reporta diferencias para revisión humana; la corrección de esas diferencias la realiza una persona, no un proceso automático.
- El procedimiento de rollback consiste en volver a aplicar la última configuración versionada conocida como estable, no en una función de "deshacer" automática independiente.
- El frontend (mailysoft-web), aunque todavía no existe como proyecto de código, se representa en la configuración como un servicio deshabilitado o pendiente, listo para habilitarse cuando su código exista.
- Los tamaños de cómputo y el número de réplicas de cada servicio usan valores por defecto razonables de Railway salvo que la configuración del entorno indique otra cosa explícitamente.
- No existe, por ahora, un marco regulatorio externo formal (tipo HIPAA o RGPD específico) que aplique a la plataforma; los controles de seguridad vigentes son los definidos por la constitución del repositorio (cifrado en tránsito/reposo, mínimo privilegio), sin requisitos adicionales de auditoría externa, acuerdos de procesamiento de datos o residencia legal de datos en esta fase.
- La región exacta de Azure donde reside hoy `mailysoft-db` no está confirmada en esta especificación; se asume que el equipo la determinará como valor de configuración al elegir la región de Railway más cercana (FR-017), sin que ese valor quede fijado en este documento.
