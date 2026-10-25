# modules/tags/common

Traduce las 5 etiquetas obligatorias del Principio VII de la constitución a un mapa de
variables de entorno de introspección, para proveedores (como Railway) que no soportan tags
nativas de clave-valor (ver [research.md](../../../specs/001-railway-deployment/research.md)
sección 5). No crea ningún recurso.

## Entradas

| Variable | Tipo | Obligatoria | Descripción |
|---|---|---|---|
| `tags` | `object({ proyecto, servicio, entorno, propietario, gestionado_por })` | sí | Las 5 etiquetas obligatorias |

## Salidas

| Output | Tipo | Descripción |
|---|---|---|
| `introspection_vars` | `map(string)` | `TAG_PROYECTO`, `TAG_SERVICIO`, `TAG_ENTORNO`, `TAG_PROPIETARIO`, `TAG_GESTIONADO_POR` |

## Ejemplo de uso

```hcl
module "tags" {
  source = "../../tags/common"

  tags = {
    proyecto       = "mailysoft"
    servicio       = "usuarios-api"
    entorno        = "dev"
    propietario    = "equipo-plataforma"
    gestionado_por = "terraform"
  }
}

# merge(var.env_vars, module.tags.introspection_vars) al inyectar variables al servicio
```
