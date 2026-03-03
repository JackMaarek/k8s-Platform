# detector.tf
# Resource: aws_guardduty_detector
#
# SOC2 CC7.1 — threat detection on all AWS accounts.
# Detects: compromised credentials, crypto mining, recon, lateral movement.
# Cost: ~$4/month per 1M events in eu-west-3. Disable in dev to reduce cost.

resource "aws_guardduty_detector" "this" {
  enable = var.enabled

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true # detect threats in EKS audit logs
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = merge(var.tags, {
    Compliance = "SOC2"
  })
}
