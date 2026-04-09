# backend.tf.template
# Remote state for domains/organization — management account scope.
# This file is a TEMPLATE. platform-bot generates backend.tf from it.

terraform {
  backend "s3" {
    bucket         = "k8s-platform-terraform-state-__AWS_ACCOUNT_ID_ORG__"
    key            = "domains/organization/terraform.tfstate"
    region         = "eu-west-3"
    encrypt        = true
    dynamodb_table = "k8s-platform-terraform-locks"
  }
}
