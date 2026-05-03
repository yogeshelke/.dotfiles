# Modules and Providers Reference

## AWS Provider
- Pin version: `required_providers { aws = { source = "hashicorp/aws", version = "~> 5.0" } }`
- Configure default tags at provider level
- Use `assume_role` for cross-account access
- Multiple provider configurations with aliases for multi-region
- Use `ignore_tags` for externally managed tags

## Provider Best Practices
- Always declare `required_providers` with source and version constraints
- Use `~>` for minor version flexibility (e.g., `~> 5.0`)
- Lock versions with `.terraform.lock.hcl` (commit to version control)
- Review provider changelogs before upgrading

## Module Structure
```
module/
├── main.tf          # Primary resources
├── variables.tf     # Input variables
├── outputs.tf       # Output values
├── versions.tf      # Provider requirements
├── README.md        # Documentation
└── examples/        # Usage examples
```

## Module Design Principles
- Single responsibility; one concern per module
- Use semantic versioning for releases
- Document all variables and outputs
- Provide sensible defaults where possible
- Use `validation` blocks on variables for input constraints
- Output computed values that consumers need

## Module Sources
- Terraform Registry: `source = "terraform-aws-modules/vpc/aws"`
- GitHub: `source = "github.com/org/repo//path?ref=v1.0.0"`
- Local: `source = "./modules/my-module"`
- S3: `source = "s3::https://bucket.s3.amazonaws.com/module.zip"`
- Always pin version with `version` or `ref`

## Key AWS Modules (Registry)
- **VPC**: https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
- **EKS**: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
- **RDS**: https://registry.terraform.io/modules/terraform-aws-modules/rds/aws/latest
- **IAM**: https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest
- **S3**: https://registry.terraform.io/modules/terraform-aws-modules/s3-bucket/aws/latest
- **KMS**: https://registry.terraform.io/modules/terraform-aws-modules/kms/aws/latest
- **ACM**: https://registry.terraform.io/modules/terraform-aws-modules/acm/aws/latest