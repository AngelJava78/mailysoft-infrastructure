variable "tags" {
  type = object({
    proyecto       = string
    servicio       = string
    entorno        = string
    propietario    = string
    gestionado_por = string
  })
  description = "Las 5 etiquetas obligatorias del Principio VII de la constitucion."
}
