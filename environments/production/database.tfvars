# production usa la base de datos logica REAL de pacientes, en el servidor ya existente en
# Azure (FR-006: solo se referencia, nunca se crea ni destruye desde este repositorio).
azure_resource_group_name = "<resource group donde vive mailysoft-db>"
azure_db_server_name      = "mailysoft-db"
azure_db_server_type      = "flexible"
azure_db_database_name    = "mailysoft"
azure_key_vault_id        = "<key_vault_id de la salida de bootstrap/azure-backend>"
