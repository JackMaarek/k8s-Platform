# backend.tf
# Remote state for _core/shared — staging environment.
# This state is the source of truth consumed by all domain remote_state data sources.

terraform {
  backend "s3" {
    bucket         = "k8s-platform-terraform-state-__AWS_ACCOUNT_ID_DEV__"
    key            = "core/shared/staging/terraform.tfstate"
    region         = "eu-west-3"
    encrypt        = true
    dynamodb_table = "k8s-platform-terraform-locks"
  }
}
