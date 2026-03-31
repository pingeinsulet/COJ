# Terraform is run per-environment from environments/<env>/.
# Example (nonprod):
#   cd environments/nonprod && terraform init && terraform plan -var-file=nonprod.tfvars
# Do not run terraform from repo root; use environments/dev, environments/nonprod, or environments/prod.
