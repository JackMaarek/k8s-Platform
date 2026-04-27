# backend.tf.template
# Remote state for _core/shared — dev environment.
# This file is a TEMPLATE. platform-bot generates backend.tf from it.

terraform {
  backend "s3" {
    bucket         = "k8s-platform-terraform-state-"
    key            = "core/shared/dev/terraform.tfstate"
    region         = "eu-west-3"
    encrypt        = true
    dynamodb_table = "k8s-platform-terraform-locks"
  }
}
