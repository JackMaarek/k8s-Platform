terraform {
  backend "s3" {
    bucket         = "k8s-platform-terraform-state-351457945908"
    key            = "core/shared/staging/terraform.tfstate"
    region         = "eu-west-3"
    encrypt        = true
    dynamodb_table = "k8s-platform-terraform-locks"
  }
}
