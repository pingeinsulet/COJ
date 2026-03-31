# Change this to deploy to a different AWS account; then update vpc_id, subnets, etc. to match.
variable "aws_account_id" {
  type        = string
  description = "AWS account ID for this environment. Single place to switch accounts."
  default     = ""
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "prefix" {
  type        = string
  description = "Prefix for resource names (e.g. jenkins-blue-green-dev)"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnet IDs"
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnet IDs"
}

variable "jenkins_controller_port" {
  type    = string
  default = "8080"
}

variable "jenkins_agent_port" {
  type    = string
  default = "50000"
}

variable "jenkins_controller_cpu" {
  type    = string
  default = "2048"
}

variable "jenkins_controller_mem" {
  type    = string
  default = "4096"
}

variable "assign_public_ip" {
  type        = bool
  description = "Assign public IP to tasks (needed for ECR pull when no NAT)."
  default     = false
}

variable "alb_internal" {
  type        = bool
  description = "If true, ALB is internal only. Set false for dev to allow public access."
  default     = true
}

variable "alb_acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for the ALB"
  default     = ""
}

variable "route53_zone_id" {
  type        = string
  description = "Route53 hosted zone ID"
}

variable "route53_alias_name" {
  type        = string
  description = "Route53 alias name (e.g. jenkins.dev)"
}

variable "jenkins_agent_secret_name" {
  type        = string
  description = "Secrets Manager secret name for persistent agent JNLP secret (JSON with AGENT_SECRET key)"
  default     = ""
}

variable "expected_aws_account_id" {
  type        = string
  description = "If set, Terraform and build scripts will only run when the current AWS account ID matches. Prevents deploying to the wrong account. Leave empty to skip."
  default     = ""
}

variable "controller_blue_green" {
  type        = bool
  description = "Use CodeDeploy blue/green for the Jenkins controller. When true, new deployments go to the inactive target group and traffic is switched after healthy."
  default     = true
}

variable "jenkins_webserver_hostname" {
  type        = string
  description = "Hostname for Jenkins UI (e.g. jenkins.dev.insulet.com). Set as WEBSERVER in Jenkins global env for jobs."
  default     = ""
}
