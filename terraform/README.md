# Terraform Infrastructure as Code

## Overview
Complete AWS infrastructure for EKS cluster with VPC, networking, and supporting resources.

## Structure
```
terraform/
├── modules/           # Reusable Terraform modules
│   ├── vpc/           # VPC with public/private subnets
│   ├── eks/           # EKS cluster control plane
│   └── nodegroup/     # EKS managed node groups
└── environments/      # Environment-specific configurations
    ├── dev/           # Development environment
    ├── staging/       # Staging environment
    └── prod/          # Production environment
```

## Prerequisites
- Terraform 1.6+
- AWS CLI configured with appropriate credentials
- S3 bucket for Terraform state
- DynamoDB table for state locking

## Initial Setup

### Create State Backend
```bash
# Create S3 bucket for state
aws s3 mb s3://your-terraform-state-bucket --region us-west-2

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-lock-table \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-west-2
```

## Usage

### Development Environment
```bash
cd environments/dev

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply infrastructure
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name dev-k8s-cluster

# Verify cluster access
kubectl get nodes
```

### Staging Environment
```bash
cd environments/staging
terraform init
terraform plan
terraform apply
```

### Production Environment
```bash
cd environments/prod
terraform init
terraform plan
terraform apply
```

## Module Documentation

### VPC Module
Creates a production-ready VPC with:
- Public and private subnets across multiple AZs
- Internet Gateway for public subnet access
- NAT Gateways for private subnet egress (one per AZ)
- Route tables with appropriate routes
- Proper tagging for EKS integration

**Inputs:**
- `environment`: Environment name (dev/staging/prod)
- `vpc_cidr`: VPC CIDR block
- `private_subnet_cidrs`: List of private subnet CIDRs
- `public_subnet_cidrs`: List of public subnet CIDRs
- `availability_zones`: List of AZs to use
- `tags`: Common tags for all resources

**Outputs:**
- `vpc_id`: VPC ID
- `private_subnet_ids`: List of private subnet IDs
- `public_subnet_ids`: List of public subnet IDs

### EKS Module
Creates EKS cluster with:
- IAM roles and policies
- Control plane with specified Kubernetes version
- Public and private API endpoint access
- Cluster logging enabled
- Security group configuration

**Inputs:**
- `cluster_name`: EKS cluster name
- `kubernetes_version`: Kubernetes version (default: 1.28)
- `private_subnet_ids`: Private subnets for worker nodes
- `public_subnet_ids`: Public subnets for load balancers
- `public_access_cidrs`: CIDR blocks for API access
- `tags`: Common tags

**Outputs:**
- `cluster_id`: EKS cluster ID
- `cluster_endpoint`: API server endpoint
- `cluster_security_group_id`: Cluster security group
- `cluster_arn`: Cluster ARN
- `cluster_certificate_authority_data`: CA data (sensitive)

### Node Group Module
Creates managed node groups with:
- IAM roles with required policies
- Launch templates with security best practices
- Scaling configuration
- Update strategy

## Cost Considerations

### Estimated Monthly Costs (us-west-2)
- EKS Control Plane: ~$73/month
- NAT Gateways (3): ~$97/month
- EC2 Instances (t3.medium, 3 nodes): ~$90/month
- Data Transfer: Variable
- **Total: ~$260-300/month for dev environment**

### Cost Optimization
- Use Spot instances for non-critical workloads
- Scale down non-prod environments outside business hours
- Use single NAT gateway for dev/staging
- Monitor and right-size instance types
- Implement cluster autoscaling

## Security Best Practices

1. **Network Isolation**: Private subnets for worker nodes
2. **API Access**: Restrict public access CIDRs in production
3. **IAM**: Least privilege for all roles
4. **Logging**: Enable all cluster log types
5. **Encryption**: Enable encryption at rest for EBS volumes
6. **Secrets**: Use AWS Secrets Manager or Parameter Store

## Troubleshooting

### State Lock Issues
```bash
# View locks
aws dynamodb get-item \
  --table-name terraform-lock-table \
  --key '{"LockID":{"S":"your-state-path"}}'

# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

### EKS Access Issues
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name <cluster-name>

# Test API access
kubectl get svc

# Check IAM authenticator
aws sts get-caller-identity
```

### Resource Cleanup
```bash
# Destroy environment
cd environments/dev
terraform destroy

# Verify all resources deleted
aws eks list-clusters --region us-west-2
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=dev"
```

## Maintenance

### Updating Modules
1. Make changes to module files
2. Update module version in environment configs
3. Test in dev environment
4. Promote to staging, then production

### Kubernetes Version Upgrades
1. Review [EKS Kubernetes versions](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)
2. Test in dev environment
3. Update `kubernetes_version` variable
4. Apply with `terraform apply`
5. Update addons if needed

## References
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
