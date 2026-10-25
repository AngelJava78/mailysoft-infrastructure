# IMPORTANTE: staging apunta al MISMO servidor que production (es el unico que existe hoy
# en Azure), pero a una base de datos logica DISTINTA (database_name) para aislar los datos
# de prueba de los datos reales de pacientes. Esa base de datos logica debe existir de
# antemano en el servidor (modules/database/azure-existing solo lee, nunca crea - FR-006).
azure_resource_group_name = "<resource group donde vive mailysoft-db>"
azure_db_server_name      = "mailysoft-db"
azure_db_server_type      = "flexible"
azure_db_database_name    = "mailysoft_staging"
azure_key_vault_id        = "<key_vault_id de la salida de bootstrap/azure-backend>"
