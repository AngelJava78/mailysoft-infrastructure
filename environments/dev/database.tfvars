# Entidad "Recurso de base de datos externo" (data-model.md). Nunca contiene la credencial
# real: solo identificadores del recurso Azure ya existente y del Key Vault que guarda el
# secreto (FR-006, FR-011).
#
# IMPORTANTE: dev y staging apuntan al MISMO servidor PostgreSQL que production (es el unico
# que existe hoy en Azure), pero a una base de datos logica DISTINTA dentro de ese servidor
# (database_name), para que un error en dev/staging nunca toque datos reales de pacientes.
# Esta base de datos logica ("mailysoft_dev") debe existir de antemano en el servidor — si
# aun no existe, crearla una sola vez fuera de este modulo (modules/database/azure-existing
# solo lee, nunca crea - FR-006) antes del primer despliegue de este entorno.
azure_resource_group_name = "<resource group donde vive mailysoft-db>"
azure_db_server_name      = "mailysoft-db"
azure_db_server_type      = "flexible"
azure_db_database_name    = "mailysoft_dev"
azure_key_vault_id        = "<key_vault_id de la salida de bootstrap/azure-backend>"
