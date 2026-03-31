# Terraform state bootstrap (us-east-2)

Creates per-environment S3 buckets and DynamoDB lock tables for Terraform state in **us-east-2**.

## One-time setup

1. **Create state resources** (from repo root):

   ```bash
   cd environments/bootstrap
   terraform init
   terraform apply
   ```

2. If S3 reports "bucket already exists" (names are globally unique), use a unique prefix:

   ```bash
   terraform apply -var="bucket_prefix=mycompany-jenkins-blue-green"
   ```

   Then update each environment's `backend.tf` to use the bucket and table names shown in the apply output (or from `terraform output backend_config`).

## Resources created

| Environment | S3 bucket                         | DynamoDB table                    |
|-------------|-----------------------------------|-----------------------------------|
| dev         | `jenkins-blue-green-tfstate-dev`  | `jenkins-blue-green-tfstate-dev`  |
| nonprod     | `jenkins-blue-green-tfstate-nonprod` | `jenkins-blue-green-tfstate-nonprod` |
| prod        | `jenkins-blue-green-tfstate-prod` | `jenkins-blue-green-tfstate-prod` |

All resources are in **us-east-2**. Buckets have versioning and encryption enabled.

## After bootstrap

- **Dev**: `cd environments/dev && terraform init -migrate-state` (migrate from local state if you had existing state).
- **Nonprod/Prod**: `cd environments/<env> && terraform init` (no migration if this is first use of the new backend).
