# Prefix for naming resources
variable "prefix" {
  type        = string
  description = "A prefix to be used in naming resources for better organization."
}

# List of private subnet IDs
variable "private_subnets" {
  type        = list(string)
  description = "A list of private subnet IDs for the infrastructure."
}

# List of public subnet IDs
variable "public_subnets" {
  type        = list(string)
  description = "A list of public subnet IDs for the infrastructure."
}

# ID of the VPC
variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where the resources will be deployed."
}

# Port used by the Jenkins controller
variable "jenkins_controller_port" {
  type        = string
  description = "The port number used by the Jenkins controller for communication."
}

# Port used by Jenkins agents
variable "jenkins_agent_port" {
  type        = string
  description = "The port number used by Jenkins agents for communication with the controller."
}

# AWS region where the infrastructure will be deployed
variable "aws_region" {
  type        = string
  description = "The AWS region where the infrastructure will be deployed (e.g., us-east-2)."
}

# CPU configuration for the Jenkins controller
variable "jenkins_controller_cpu" {
  type        = string
  description = "The CPU configuration for the Jenkins controller, specified as needed for the environment."
}

# Memory configuration for the Jenkins controller
variable "jenkins_controller_mem" {
  type        = string
  description = "The memory configuration for the Jenkins controller, specified as needed for the environment."
}

# When true, Fargate tasks get a public IP so they can pull from ECR when subnets have no NAT (e.g. dev).
variable "assign_public_ip" {
  type        = bool
  description = "Assign public IP to controller tasks (needed for ECR pull when no NAT gateway)."
  default     = false
}

# Set to false for a public ALB (e.g. dev so you can reach Jenkins from the internet)
variable "alb_internal" {
  type        = bool
  description = "If true, ALB is internal only. Set false for dev to allow public access."
  default     = true
}

# ACM Certificate for the alb
variable "alb_acm_certificate_arn" {
  type        = string
  description = "The ACM certificate ARN to use for the alb. Leave empty for HTTP-only (dev)."
  default     = ""
}

# Specify the ID of the Route 53 hosted zone
variable "route53_zone_id" {
  type        = string
  description = "The ID of the Route 53 hosted zone where the alias will be configured"
  default     = ""
}

# Specify the alias name for Route 53
variable "route53_alias_name" {
  type        = string
  description = "The alias name to be configured in Route 53"
  default     = ""
}

# Name of the secret in AWS Secrets Manager containing the persistent agent JNLP secret
variable "jenkins_agent_secret_name" {
  type        = string
  description = "Name of the secret in AWS Secrets Manager containing the agent secret. Secret should be JSON with key 'AGENT_SECRET'. Leave empty to configure manually."
  default     = ""
}

# Optional: set to the AWS account ID where this environment must run. Terraform will fail plan/apply if the current account does not match (safety check).
variable "expected_aws_account_id" {
  type        = string
  description = "If set, Terraform will only run when the current AWS account ID matches this value. Prevents deploying to the wrong account. Leave empty to skip the check."
  default     = ""
}

# Enable blue/green deployment for the Jenkins controller (CodeDeploy + two target groups).
variable "controller_blue_green" {
  type        = bool
  description = "Use CodeDeploy blue/green for the controller: two ALB target groups, deploy to inactive, then switch traffic. Set false for rolling deployments. Enabling may require replacing the ECS service (see docs)."
  default     = false
}

# CloudWatch log retention (days). Set to 0 to retain logs indefinitely.
variable "cloudwatch_log_retention_days" {
  type        = number
  description = "Number of days to retain Jenkins ECS logs in CloudWatch. 0 = never expire."
  default     = 30
}

# Hostname for the Jenkins UI (e.g. jenkins.dev.insulet.com). Exposed as WEBSERVER in Jenkins global env for use in jobs.
variable "jenkins_webserver_hostname" {
  type        = string
  description = "Public hostname for Jenkins (e.g. jenkins.dev.insulet.com). Set as WEBSERVER in Jenkins global environment."
  default     = ""
}