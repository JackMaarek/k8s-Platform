# secret.tf
# Resources: aws_secretsmanager_secret, aws_secretsmanager_secret_version

resource "aws_secretsmanager_secret" "this" {
  name                    = "${var.path}/${var.name}"
  description             = var.description
  recovery_window_in_days = var.recovery_window_days

  tags = merge(var.tags, {
    Domain = var.domain
    Name   = var.name
  })
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = var.secret_string

  lifecycle {
    ignore_changes = [secret_string]
  }
}
