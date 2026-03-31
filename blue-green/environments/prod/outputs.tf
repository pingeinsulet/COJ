output "controller_ecr_repository_url" {
  value       = module.jenkins.controller_ecr_repository_url
  description = "ECR URL for Jenkins controller image"
}

output "agent_ecr_repository_url" {
  value       = module.jenkins.agent_ecr_repository_url
  description = "ECR URL for Jenkins agent image"
}

output "controller_ecr_registry" {
  value       = module.jenkins.controller_ecr_registry
  description = "ECR registry endpoint (for docker login)"
}

output "agent_ecr_registry" {
  value       = module.jenkins.agent_ecr_registry
  description = "ECR registry endpoint for agent"
}

output "jenkins_config_path" {
  value       = module.jenkins.jenkins_config_path
  description = "Path to generated jenkins.yaml for controller build"
}

output "aws_region" {
  value       = module.jenkins.aws_region
  description = "AWS region"
}

output "prefix" {
  value       = module.jenkins.prefix
  description = "Environment prefix for resource naming"
}

output "controller_url" {
  value       = module.jenkins.controller_url
  description = "External Jenkins URL (ALB DNS)"
}

output "controller_alb_dns_name" {
  value       = module.jenkins.controller_alb_dns_name
  description = "ALB DNS name (host only)"
}
