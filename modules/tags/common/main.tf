# Railway no tiene un sistema de tags clave-valor nativo (research.md seccion 5). Este
# modulo no crea ningun recurso: solo traduce las 5 etiquetas obligatorias del Principio VII
# a un mapa de variables de entorno de introspeccion, que el modulo llamador inyecta en el
# servicio junto a env_vars. La convencion de nombres mailysoft-<servicio>-<entorno> ya
# codifica proyecto/servicio/entorno en el propio nombre del recurso; este mapa las hace
# tambien visibles desde dentro del servicio y desde Terraform state.
locals {
  introspection_vars = {
    TAG_PROYECTO       = var.tags.proyecto
    TAG_SERVICIO       = var.tags.servicio
    TAG_ENTORNO        = var.tags.entorno
    TAG_PROPIETARIO    = var.tags.propietario
    TAG_GESTIONADO_POR = var.tags.gestionado_por
  }
}
