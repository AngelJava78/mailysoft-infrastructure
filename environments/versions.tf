# required_version confirmado 2026-11-09 contra la version real instalada (Terraform v1.17.1,
# research.md Fase 001-railway-deployment, seccion 7). Un solo root compartido por los tres
# entornos (ADR 0007).
terraform {
  required_version = "~> 1.17.0"

  required_providers {
    railway = {
      source  = "terraform-community-providers/railway"
      version = "0.6.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3" # modules/database/railway-managed (002-single-provider-deployment)
    }
  }
  # Sin "azurerm" a proposito (ADR 0005): este root es 100% Railway y no referencia ningun
  # modulo que lo requiera.
}
