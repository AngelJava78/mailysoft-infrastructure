# ADR 0002: App Service para las dos aplicaciones públicas, Container Apps para las seis APIs

**Estado**: Aceptado
**Fecha**: 2026-11-08
**Contexto**: [specs/002-single-provider-deployment](../../specs/002-single-provider-deployment/)

## Contexto

La Fase 2 convierte Azure en un proveedor de cómputo completo (hasta ahora,
`modules/service/azure` era un stub que siempre fallaba — FR-005 de
`001-railway-deployment`). Hay que elegir qué recurso de Azure representa a las ocho
aplicaciones de la plataforma, y cómo lograr que las seis APIs nunca tengan acceso público
(FR-004) mientras las dos aplicaciones web sí lo tienen (FR-003).

Durante la investigación (ver
[research.md](../../specs/002-single-provider-deployment/research.md) sección 1) se
encontró que:

- Un *Container Apps Environment* **interno** deja a un servicio sin dominio público "de
  fábrica", sin pasos adicionales.
- Lograr lo mismo con App Service exige deshabilitar el acceso público y añadir un
  *Private Endpoint* por servicio — repetido seis veces para las APIs.
- App Service, en cambio, es la opción más simple para un servicio que sí necesita endpoint
  público nativo y dominio personalizado, como las dos aplicaciones web.

## Decisión

- `maily-backoffice` y `maily-frontend` (`domain_type = "public"`): **Azure App Service**
  (Linux, contenedor), con *Regional VNet Integration* de salida hacia `subred-apis`.
- Las seis APIs (`domain_type = "private"`): **Azure Container Apps**, dentro de un
  *Container Apps Environment* **compartido** (creado una sola vez por entorno en
  `modules/network-domain/azure`, no una vez por API), con `ingress.external_enabled = false`.

## Alternativas consideradas

- **Azure Container Apps para las ocho**: rechazada para las dos aplicaciones públicas porque
  complica el dominio público/certificados frente al endpoint nativo de App Service, sin
  ninguna ventaja de aislamiento para un servicio que de todas formas debe ser público.
- **Azure App Service para las ocho, con Private Endpoint en las seis APIs**: rechazada
  porque exige seis *Private Endpoints* adicionales para lograr lo que un *Environment*
  interno da sin configuración adicional.
- **Azure Kubernetes Service (AKS)**: rechazada por desproporcionada para ocho servicios sin
  estado propio.

## Consecuencias

- `modules/service/azure` implementa dos ramas de recurso distintas detrás de la misma
  interfaz común (contracts/service-module-interface.md de la Fase 1, sin cambios), en vez
  de un único tipo de recurso para los ocho servicios.
- El Container Apps Environment compartido vive en `modules/network-domain/azure` (no en
  `modules/service/azure`), precisamente para que se cree una sola vez por entorno.
- Azure no construye desde un repositorio (a diferencia de Railway vía Nixpacks): cada
  servicio en Azure necesita una imagen ya publicada (`container_image`), con un valor por
  omisión derivado de `source_repo`/`source_ref` documentado en
  `modules/service/azure/README.md`.
