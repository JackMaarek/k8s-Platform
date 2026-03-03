# backend.tf
# Remote state for domains/platform — dev environment.

terraform {
  backend "s3" {
    bucket         = "k8s-platform-terraform-state-__AWS_ACCOUNT_ID_DEV__"
    key            = "domains/platform/dev/terraform.tfstate"
    region         = "eu-west-3"
    encrypt        = true
    dynamodb_table = "k8s-platform-terraform-locks"
  }
}
