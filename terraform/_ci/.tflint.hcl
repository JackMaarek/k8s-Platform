# .tflint.hcl
# TFLint configuration — enforces code quality across all Terraform code.
# Run: tflint --recursive from repo root.

plugin "aws" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

config {
  format              = "compact"
  call_module_type    = "local"
  force               = false
  disabled_by_default = false
}

# Enforce all variables have descriptions
rule "terraform_documented_variables" {
  enabled = true
}

# Enforce all outputs have descriptions
rule "terraform_documented_outputs" {
  enabled = true
}

# Enforce naming conventions
rule "terraform_naming_convention" {
  enabled = true

  variable {
    format = "snake_case"
  }

  output {
    format = "snake_case"
  }

  resource {
    format = "snake_case"
  }

  module {
    format = "snake_case"
  }
}

# Require type constraints on variables
rule "terraform_typed_variables" {
  enabled = true
}

# Disallow deprecated interpolation syntax
rule "terraform_deprecated_interpolation" {
  enabled = true
}

# Warn on unused declarations
rule "terraform_unused_declarations" {
  enabled = true
}
