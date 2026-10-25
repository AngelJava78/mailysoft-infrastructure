# Stub: el proveedor "azure" para servicios de computo (APIs/backoffice/frontend) no esta
# operativo en esta fase (FR-005). Este modulo nunca crea recursos; su unico proposito es
# fallar la validacion de forma explicita y temprana (terraform validate / plan), antes de
# cualquier intento de apply, para que elegir "azure" nunca produzca un fallo inesperado ni
# un cambio parcial. La validacion que produce ese fallo vive en variables.tf.
#
# La base de datos de Azure (mailysoft-db) es un caso distinto: se referencia como recurso
# externo existente desde modules/database/azure-existing, que si esta operativo.
