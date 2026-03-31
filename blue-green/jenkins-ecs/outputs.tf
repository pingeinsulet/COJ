output "controller_ecr_repository_url" {
  description = "ECR repository URL for the Jenkins controller image"
  value       = aws_ecr_repository.jenkins_nonprod_controller_repo.repository_url
}

output "agent_ecr_repository_url" {
  description = "ECR repository URL for the Jenkins agent image (used by persistent and ECS agents)"
  value       = aws_ecr_repository.jenkins_nonprod_agent_repo.repository_url
}

output "controller_ecr_registry" {
  description = "ECR registry endpoint (for docker login)"
  value       = local.controller_repo_endpoint
}

output "agent_ecr_registry" {
  description = "ECR registry endpoint for agent (for docker login)"
  value       = local.agent_repo_endpoint
}

output "jenkins_config_path" {
  description = "Path to the generated jenkins.yaml for this environment (for controller image build)"
  value       = abspath(local_file.jenkins_nonprod_config.filename)
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "prefix" {
  description = "Environment prefix used for resource naming"
  value       = var.prefix
}

# External URL for the Jenkins controller (ALB DNS). Same design for dev, nonprod, prod.
output "controller_url" {
  description = "External URL for the Jenkins controller (ALB DNS, e.g. http://jenkins-blue-green-prod-alb-xxxx.us-east-2.elb.amazonaws.com/)"
  value       = "http://${aws_lb.nonprod_alb.dns_name}/"
}

output "controller_alb_dns_name" {
  description = "ALB DNS name for the Jenkins controller (host only, no scheme or path)"
  value       = aws_lb.nonprod_alb.dns_name
}
