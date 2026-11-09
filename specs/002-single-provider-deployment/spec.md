# Feature Specification: Despliegue de MailySoft en un Solo Proveedor — Railway o Azure (Fase 2 Multi-Nube)

**Feature Branch**: `002-single-provider-deployment`

**Created**: 2026-11-08

**Status**: Draft

**Input**: User description: "Basados en los mensajes que te he indicado y en los diagramas, adapta el código actual de Terraform para hacer el despliegue en Railway Azure. Considera que todo se despliegue en Railway o todo se despliegue en Azure."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Elegir un único proveedor para todo un entorno (Priority: P1)

Como desarrollador, quiero elegir Railway o Azure como el único proveedor de un entorno completo, para desplegar las dos aplicaciones web, las seis APIs y la base de datos de ese entorno sin combinar proveedores por accidente.

**Why this priority**: Es el cambio central que pide esta fase: hoy Azure rechaza cualquier intento de desplegar cómputo (backoffice, frontend o APIs), y no existe una forma declarada de decir "este entorno completo va a un solo proveedor". Sin esto no hay manera de ofrecer Azure como alternativa real a Railway.

**Independent Test**: Puede probarse configurando un entorno vacío con proveedor Azure, ejecutando el pipeline de despliegue, y verificando que las dos aplicaciones web, las seis APIs y la base de datos quedan desplegadas en Azure sin que el sistema rechace la operación.

**Acceptance Scenarios**:

1. **Given** un entorno configurado con proveedor Railway para todos sus servicios y su base de datos, **When** se ejecuta el pipeline de despliegue y se aprueba el cambio, **Then** las dos aplicaciones web, las seis APIs y la base de datos quedan desplegadas en Railway.
2. **Given** un entorno configurado con proveedor Azure para todos sus servicios y su base de datos, **When** se ejecuta el pipeline de despliegue y se aprueba el cambio, **Then** las dos aplicaciones web, las seis APIs y la base de datos quedan desplegadas en Azure, sin el rechazo de "proveedor no disponible" que existía antes de esta fase.

---

### User Story 2 - Mantener las APIs y la base de datos fuera del alcance de internet (Priority: P1)

Como responsable técnico, quiero que ninguna de las seis APIs ni la base de datos puedan recibir tráfico directo desde internet en ningún proveedor, para que las dos aplicaciones web sean la única puerta de entrada pública de la plataforma.

**Why this priority**: Es un requisito de seguridad, no una mejora opcional: los datos de pacientes y de usuarios pasan por esas seis APIs y por la base de datos. Abrir cualquiera de ellas a internet por descuido es el riesgo que esta historia existe para cerrar, en los dos proveedores por igual.

**Independent Test**: Puede probarse, tras un despliegue en cada proveedor, intentando alcanzar desde fuera del entorno la dirección de cualquiera de las seis APIs o de la base de datos, y verificando que ninguna responde.

**Acceptance Scenarios**:

1. **Given** un entorno desplegado en Railway, **When** se intenta acceder desde internet a cualquiera de las seis APIs o a la base de datos, **Then** la conexión no tiene éxito porque ninguna expone un dominio público.
2. **Given** un entorno desplegado en Azure, **When** se intenta acceder desde internet a cualquiera de las seis APIs o a la base de datos, **Then** la conexión se rechaza en la red antes de llegar al servicio.
3. **Given** cualquiera de los dos proveedores, **When** una de las dos aplicaciones web o una API necesita llamar a otra API del mismo entorno, **Then** esa llamada se completa normalmente porque el servicio de destino sigue siendo alcanzable dentro del entorno.

---

### User Story 3 - Incorporar las APIs nuevas de la plataforma (Priority: P2)

Como desarrollador, quiero añadir las APIs de clínicas, agenda y catálogo público, y habilitar el frontend de clínicas, con el mismo mecanismo de configuración que ya usan los servicios existentes, para que la plataforma completa quede representada sin escribir configuración duplicada.

**Why this priority**: Estas APIs y el frontend ya tienen código real; la infraestructura todavía no las conoce. Sin esta historia, la Historia 1 desplegaría una plataforma incompleta.

**Independent Test**: Puede probarse añadiendo la configuración de una de estas APIs a un entorno con los demás servicios ya desplegados, y verificando que queda desplegada tras su aprobación sin modificar la definición de los servicios existentes.

**Acceptance Scenarios**:

1. **Given** un entorno con los servicios existentes ya desplegados, **When** se agrega la configuración de una API nueva de la plataforma, **Then** esa API queda desplegada tras su aprobación sin modificar los servicios ya existentes.
2. **Given** el frontend de clínicas, hoy declarado pero deshabilitado, **When** se habilita en la configuración de un entorno, **Then** queda desplegado con acceso público en ese entorno.

---

### User Story 4 - Aprovisionar la base de datos sin arriesgar la que ya existe (Priority: P2)

Como responsable técnico, quiero que elegir Railway como proveedor de un entorno aprovisione una base de datos propia de ese entorno sin tocar la base que ya existe en Azure, para no poner en riesgo los datos reales de pacientes mientras se evalúa la alternativa.

**Why this priority**: La base de datos existente guarda datos reales de pacientes. Cualquier camino que pudiera leerla, copiarla o recrearla al elegir otro proveedor es un riesgo que debe quedar cerrado antes de que Azure o Railway compitan como opción completa.

**Independent Test**: Puede probarse desplegando un entorno con proveedor Railway y verificando, después, que la base de datos existente en Azure no registra ningún cambio, conexión de escritura adicional ni intento de recreación.

**Acceptance Scenarios**:

1. **Given** un entorno configurado con proveedor Railway y sin base de datos previa en ese entorno, **When** se ejecuta el pipeline de despliegue, **Then** se aprovisiona una base de datos nueva en Railway y la base de datos existente en Azure permanece intacta.
2. **Given** un entorno configurado con proveedor Azure, **When** se ejecuta el pipeline de despliegue, **Then** el sistema sigue referenciando la base de datos ya existente en Azure, igual que en la fase anterior, sin intentar crearla ni destruirla.

---

### User Story 5 - Ver qué tanto aislamiento impone cada proveedor antes de aprobar (Priority: P3)

Como responsable técnico, quiero que la previsualización de cambios indique si el aislamiento entre las APIs y la base de datos queda garantizado por la red o solo por las credenciales entregadas a cada servicio, para decidir con esa información si apruebo el cambio.

**Why this priority**: Los dos proveedores no ofrecen la misma garantía. Aprobar un cambio sin saber cuál de las dos aplica es aprobar a ciegas un riesgo distinto según el proveedor elegido.

**Independent Test**: Puede probarse generando una previsualización para un entorno en cada proveedor y verificando que el texto de la previsualización distingue explícitamente el tipo de garantía de ese proveedor.

**Acceptance Scenarios**:

1. **Given** una previsualización para un entorno en Railway, **When** se revisa su contenido, **Then** se indica qué servicios recibirán las credenciales de la base de datos y que esa es la única garantía de aislamiento disponible en ese proveedor.
2. **Given** una previsualización para un entorno en Azure, **When** se revisa su contenido, **Then** se indica que el acceso entre servicios queda restringido también por reglas de red, no solo por credenciales.

---

### Edge Cases

- ¿Qué ocurre si la configuración de un entorno asigna proveedores distintos a sus propios servicios o a su base de datos, en lugar de elegir uno solo? El sistema debe advertirlo explícitamente en la previsualización y exigir confirmación: esta fase asume un proveedor único por entorno como configuración de referencia, sin eliminar la posibilidad de mezclar proveedores por servicio que ya permite el Principio II.
- ¿Qué ocurre si se elige Azure para un entorno antes de que su configuración de reglas de red entre servicios esté completa? La validación debe fallar antes de generar la previsualización, igual que ocurre hoy con cualquier otra variable de configuración obligatoria.
- ¿Qué ocurre si una API nueva no declara explícitamente su tipo de dominio? Se configura como privada (sin acceso público) por omisión, nunca pública por accidente.
- ¿Qué ocurre si se elige Railway para un entorno que ya tenía una base de datos propia aprovisionada ahí en un despliegue anterior? Se reutiliza esa base de datos existente en Railway; no se crea una segunda.
- ¿Qué ocurre si se cambia el proveedor de un entorno que ya está desplegado (de Railway a Azure o de Azure a Railway)? La previsualización debe mostrarlo como el reemplazo de todos los servicios y de la base de datos de ese entorno, destacado como cambio destructivo, y requerir la misma aprobación explícita que cualquier otro cambio de ese tipo.
- ¿Qué ocurre si se habilita el frontend de clínicas en un entorno donde alguna de las APIs que necesita (agenda, clínicas) todavía no está habilitada? El sistema debe permitir igualmente el despliegue del frontend; que una llamada a una API deshabilitada falle en tiempo de ejecución es responsabilidad de la aplicación, no de esta infraestructura.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST permitir configurar, por entorno, un único proveedor de destino (Railway o Azure) que aplique a las dos aplicaciones web, a las seis APIs y a la base de datos de ese entorno.
- **FR-002**: El sistema MUST operar Azure como proveedor completo de cómputo: cuando un entorno elige Azure, MUST desplegar en él las dos aplicaciones web y las seis APIs de la plataforma, sin el rechazo de "proveedor no disponible" que aplicaba antes de esta fase.
- **FR-003**: El sistema MUST configurar únicamente las dos aplicaciones web (backoffice y frontend de clínicas) con acceso público desde internet, en cualquiera de los dos proveedores.
- **FR-004**: El sistema MUST configurar las seis APIs de la plataforma sin acceso público desde internet, en cualquiera de los dos proveedores, de forma que solo sean alcanzables desde los demás servicios del mismo entorno.
- **FR-005**: Cuando el proveedor elegido ofrezca un mecanismo de reglas de red entre servicios, el sistema MUST usarlo para que solo las seis APIs puedan alcanzar la base de datos del entorno, rechazando en la red cualquier otro origen.
- **FR-006**: Cuando el proveedor elegido no ofrezca un mecanismo de reglas de red entre servicios, el sistema MUST limitar, mediante las credenciales entregadas a cada servicio, cuáles pueden conectarse a la base de datos, entregando esas credenciales únicamente a las seis APIs.
- **FR-007**: El sistema MUST declarar explícitamente, para el proveedor activo de un entorno, si la restricción de acceso a la base de datos descrita en FR-005/FR-006 queda garantizada por la red o solo por las credenciales, y MUST mostrar esa distinción en la previsualización de cualquier cambio sobre ese entorno.
- **FR-008**: El sistema MUST permitir incorporar cada una de las APIs de la plataforma que aún no tiene configuración (clínicas, agenda y catálogo público) añadiendo únicamente su configuración, sin duplicar ni modificar la definición de los servicios ya existentes.
- **FR-009**: El sistema MUST permitir habilitar el frontend de clínicas, hoy declarado pero deshabilitado, en cualquier entorno, con acceso público, usando el mismo mecanismo de habilitación ya definido para los demás servicios.
- **FR-010**: Toda API nueva que no declare explícitamente su tipo de dominio MUST configurarse como privada (sin acceso público) por omisión.
- **FR-011**: Cuando un entorno elige Railway y no existe todavía una base de datos de ese entorno en Railway, el sistema MUST aprovisionar una base de datos nueva, distinta de la base de datos que ya existe en Azure.
- **FR-012**: El sistema MUST NOT leer, copiar, modificar ni eliminar los datos de la base de datos que ya existe en Azure como consecuencia de elegir Railway como proveedor de cualquier entorno.
- **FR-013**: Cuando un entorno elige Azure, el sistema MUST seguir tratando la base de datos ya existente en Azure como recurso externo referenciado, en los mismos términos que ya exige el Principio II (nunca creada, recreada ni destruida desde esta infraestructura).
- **FR-014**: El sistema MUST detectar y advertir, antes de aplicar cualquier cambio, cuando la configuración de un entorno asigna proveedores distintos a sus propios servicios o a su base de datos, y MUST requerir confirmación explícita para proceder con esa mezcla.
- **FR-015**: Cambiar el proveedor de un entorno ya desplegado MUST mostrarse en la previsualización como el reemplazo de todos los servicios y de la base de datos de ese entorno, y MUST requerir la misma aprobación explícita que cualquier otro cambio destructivo.
- **FR-016**: El sistema MUST mantener disponibles, para cada entorno, las mismas garantías ya exigidas en la fase anterior (previsualización revisable, aprobación explícita en producción, gestión de secretos fuera del repositorio, idempotencia) sin importar cuál de los dos proveedores esté activo.

### Key Entities *(include if feature involves data)*

- **Topología de despliegue**: la combinación de un único proveedor (Railway o Azure) elegida para las dos aplicaciones web, las seis APIs y la base de datos de un mismo entorno.
- **Aplicación pública**: maily-backoffice o el frontend de clínicas; el único tipo de servicio con acceso directo desde internet, en cualquier proveedor.
- **API de plataforma**: cualquiera de las seis APIs de la plataforma (usuarios, sistema, pacientes, catálogo público, clínicas y agenda); nunca tiene acceso público directo.
- **Garantía de aislamiento**: la forma en que el proveedor activo de un entorno impide que un servicio no autorizado alcance la base de datos — por reglas de red cuando el proveedor lo permite, o por las credenciales entregadas a cada servicio cuando no.
- **Base de datos del entorno**: ya existente y externa cuando el proveedor del entorno es Azure; nueva y propia de ese entorno cuando el proveedor es Railway y todavía no existe una ahí.

## Out of Scope

- La migración de datos reales entre la base de datos ya existente en Azure y cualquier base de datos nueva aprovisionada en Railway.
- El despliegue simultáneo y activo del mismo entorno en más de un proveedor a la vez (alta disponibilidad multi-nube); el objetivo de esta fase es un único proveedor activo por entorno.
- La Fase 3 (AWS) prevista por el Principio II.
- Construir, compilar o probar el código de los microservicios o de las dos aplicaciones web (Principio I): esta especificación solo cubre cómo se despliegan.
- Definir mecanismos de agrupación de máquinas virtuales o nodos de cómputo para reglas de red basadas en identidad de cómputo; no aplican mientras la plataforma no use cómputo basado en VMs.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un entorno completo (dos aplicaciones web, seis APIs y base de datos) puede desplegarse eligiendo un único proveedor, Railway o Azure, sin pasos manuales en ninguna consola.
- **SC-002**: En cualquiera de los dos proveedores, ninguna de las seis APIs ni la base de datos son alcanzables directamente desde internet; solo las dos aplicaciones web lo son.
- **SC-003**: Añadir cualquiera de las tres APIs nuevas de la plataforma (clínicas, agenda o catálogo público) a un entorno existente requiere únicamente cambios de configuración, sin modificar los servicios ya desplegados.
- **SC-004**: Elegir Azure como proveedor de un entorno completa el despliegue de sus dos aplicaciones web y sus seis APIs sin que el sistema rechace la operación por "proveedor no disponible".
- **SC-005**: Cuando el proveedor elegido es Railway y la base de datos de ese entorno todavía no existe ahí, el sistema la aprovisiona nueva sin leer, copiar ni modificar los datos de la base de datos ya existente en Azure, en el 100% de los despliegues auditados.
- **SC-006**: El 100% de las previsualizaciones de cambio, en cualquiera de los dos proveedores, muestran explícitamente qué servicios recibirán las credenciales de conexión a la base de datos y si esa es la única garantía de aislamiento disponible.

## Assumptions

- Esta especificación no reabre el orden de prioridad Railway → Azure → AWS del Principio II: Azure deja de ser un proveedor rechazado por diseño y pasa a ser un proveedor completo, pero Railway sigue siendo el proveedor por defecto cuando una configuración no indica otro explícitamente.
- La posibilidad de asignar un proveedor distinto a cada servicio dentro de un mismo entorno, ya permitida por el Principio II, no se elimina; esta especificación añade el modo "un solo proveedor para todo el entorno" como la configuración de referencia que el equipo usará en la práctica para comparar Railway y Azure, no como una restricción técnica nueva sobre el Principio II.
- La base de datos que hoy existe en Azure (`mailysoft-db`) permanece protegida contra recreación o destrucción, en cualquiera de los dos proveedores elegidos para un entorno, conforme al Principio II.
- Cuando el proveedor elegido para un entorno es Railway, ese entorno aprovisiona una base de datos nueva en Railway, distinta de la que ya existe en Azure; la migración de datos reales entre ambas, si llega a decidirse, es un proyecto aparte y no una consecuencia automática de elegir proveedor.
- Las tres APIs nuevas de la plataforma (clínicas, agenda y catálogo público) y el frontend de clínicas se incorporan con el mismo patrón de configuración que ya usan los servicios existentes (Principio III); ninguna requiere un módulo de infraestructura nuevo por sí misma, solo que el proveedor elegido ofrezca un módulo de cómputo operativo (lo que esta fase exige para Azure en FR-002).
- La elección de proveedor es independiente por entorno (dev, staging, production pueden elegir proveedores distintos entre sí), de la misma forma en que ya lo establecía la fase anterior para la selección de proveedor por servicio.
- Cuando el proveedor elegido es Azure, las reglas de red que aíslan a las APIs y a la base de datos del resto de la red se consideran infraestructura nueva de esta fase; cuando el proveedor elegido es Railway, no se asume la existencia de un mecanismo equivalente, y la garantía que ofrece esta fase en ese proveedor es la descrita en FR-006 (credenciales, no red).
