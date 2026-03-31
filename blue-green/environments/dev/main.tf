# Jenkins on ECS - Dev environment
# Run terraform from this directory: terraform init && terraform plan -var-file=dev.tfvars

module "jenkins" {
  source = "../../jenkins-ecs"

  aws_region               = var.aws_region
  prefix                   = var.prefix
  vpc_id                   = var.vpc_id
  jenkins_controller_port  = var.jenkins_controller_port
  jenkins_agent_port       = var.jenkins_agent_port
  private_subnets          = var.private_subnets
  public_subnets           = var.public_subnets
  jenkins_controller_cpu    = var.jenkins_controller_cpu
  jenkins_controller_mem   = var.jenkins_controller_mem
  assign_public_ip         = var.assign_public_ip
  alb_internal             = var.alb_internal
  alb_acm_certificate_arn  = var.alb_acm_certificate_arn
  route53_zone_id          = var.route53_zone_id
  route53_alias_name       = var.route53_alias_name
  jenkins_agent_secret_name = var.jenkins_agent_secret_name
  expected_aws_account_id  = var.aws_account_id != "" ? var.aws_account_id : var.expected_aws_account_id
  controller_blue_green    = var.controller_blue_green
  jenkins_webserver_hostname = var.jenkins_webserver_hostname
}
