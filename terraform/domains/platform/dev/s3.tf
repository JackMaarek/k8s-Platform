# s3.tf
# Responsibility: S3 buckets for ML workloads on the dev environment.
# QuanvNN datasets bucket — read-only access from the ml namespace via IRSA (see irsa.tf).

# ── QuanvNN datasets bucket ────────────────────────────────────────────────────
# Holds satellite imagery patches consumed by the QuanvNN training pipeline.
# Read-only from the cluster — uploads happen out-of-band (operator from a workstation).

resource "aws_s3_bucket" "quanvnn_datasets" {
  bucket        = "podyourlife-quanvnn-datasets-dev"
  force_destroy = false

  tags = {
    Component = "quanvnn-datasets"
    Workload  = "ml"
  }
}

resource "aws_s3_bucket_versioning" "quanvnn_datasets" {
  bucket = aws_s3_bucket.quanvnn_datasets.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "quanvnn_datasets" {
  bucket = aws_s3_bucket.quanvnn_datasets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "quanvnn_datasets" {
  bucket = aws_s3_bucket.quanvnn_datasets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "quanvnn_datasets" {
  bucket = aws_s3_bucket.quanvnn_datasets.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "quanvnn_datasets" {
  bucket = aws_s3_bucket.quanvnn_datasets.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}
