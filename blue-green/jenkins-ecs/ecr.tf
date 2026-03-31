# Jenkins controller repo (name includes prefix for dev/nonprod/prod)
# Lifecycle: keep ECR repo (and pushed images) across destroys so we don't have to repush after apply.
resource "aws_ecr_repository" "jenkins_nonprod_controller_repo" {
  lifecycle {
    precondition {
      condition     = var.expected_aws_account_id == "" || data.aws_caller_identity.current.account_id == var.expected_aws_account_id
      error_message = "Wrong AWS account: expected ${var.expected_aws_account_id}, but current account is ${data.aws_caller_identity.current.account_id}. Set expected_aws_account_id in tfvars to the correct account, or leave empty to skip this check."
    }
    prevent_destroy = true
  }
  name         = "${var.prefix}-controller"
  force_delete = true
}

# Jenkins agent repo
resource "aws_ecr_repository" "jenkins_nonprod_agent_repo" {
  name         = "${var.prefix}-agent"
  force_delete = true

  lifecycle {
    prevent_destroy = true
  }
}

# Grabbing the repo endpoints and setting them as local variables
locals {
  controller_repo_endpoint = split("/", aws_ecr_repository.jenkins_nonprod_controller_repo.repository_url)[0]
  agent_repo_endpoint      = split("/", aws_ecr_repository.jenkins_nonprod_agent_repo.repository_url)[0]
}

# Jenkins controller configuration - written to build/<prefix>/ so each env has its own
resource "local_file" "jenkins_nonprod_config" {
  content = templatefile("${path.module}/../docker/jenkins_controller/jenkins.yaml.tftpl", {
    ecs_agent_cluster       = aws_ecs_cluster.nonprod_agents.arn,
    region                  = var.aws_region,
    jenkins_controller_port = var.jenkins_controller_port
    jenkins_agent_port      = var.jenkins_agent_port,
    jenkins_agent_sg        = aws_security_group.jenkins_nonprod_agents.id,
    subnets                 = join(",", var.private_subnets),
    jenkins_agent_image     = aws_ecr_repository.jenkins_nonprod_agent_repo.repository_url,
    jenkins_dns             = "${aws_service_discovery_service.nonprod_controller.name}.${aws_service_discovery_private_dns_namespace.nonprod_controller.name}",
    log_group               = aws_cloudwatch_log_group.jenkins_nonprod_logs.name,
    log_stream              = aws_cloudwatch_log_stream.jenkins_nonprod_agent_log_stream.name,
    ecs_execution_role      = aws_iam_role.jenkins_nonprod_execution_role.arn,
    efsVolumeName           = "${var.prefix}-efs",
    efsVolumeId             = aws_efs_file_system.nonprod_efs.id,
    containerPath           = "/var/jenkins_home",
    accessPointId           = aws_efs_access_point.nonprod_efs_ap.id,
    jenkins_webserver_hostname = var.jenkins_webserver_hostname
  })
  filename        = "${path.module}/../docker/jenkins_controller/jenkins_${replace(var.prefix, "-", "_")}.yaml"
  file_permission = "0644"
}