plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Imponer la convencion de nombres mailysoft-<servicio>-<entorno> (Principio VII de la
# constitucion) a nivel de variable allí donde el nombre se declara como "name".
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}
