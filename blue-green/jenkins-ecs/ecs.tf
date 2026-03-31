# ECS cluster for the Jenkins controller
resource "aws_ecs_cluster" "nonprod_controller" {
  name = "${var.prefix}-controller"
}

# ECS cluster for the Jenkins agent
resource "aws_ecs_cluster" "nonprod_agents" {
  name = "${var.prefix}-agents"
}

# ECS cluster capacity provider for the Jenkins controller cluster
resource "aws_ecs_cluster_capacity_providers" "nonprod_controller" {
  cluster_name       = aws_ecs_cluster.nonprod_controller.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# ECS cluster capacity provider for the Jenkins agent cluster
resource "aws_ecs_cluster_capacity_providers" "nonprod_agents" {
  cluster_name       = aws_ecs_cluster.nonprod_agents.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# task definition for the Jenkins controller (image must be built and pushed separately)
resource "aws_ecs_task_definition" "nonprod_jenkins_td" {
  family = var.prefix
  container_definitions = templatefile(
    "${path.module}/task-definitions/jenkins.tftpl", {
      name                    = "${var.prefix}",
      image                   = aws_ecr_repository.jenkins_nonprod_controller_repo.repository_url,
      cpu                     = var.jenkins_controller_cpu,
      memory                  = var.jenkins_controller_mem,
      efsVolumeName           = "${var.prefix}-efs",
      efsVolumeId             = aws_efs_file_system.nonprod_efs.id,
      transmitEncryption      = true,
      containerPath           = "/var/jenkins_home",
      region                  = var.aws_region
      log_group               = aws_cloudwatch_log_group.jenkins_nonprod_logs.name
      log_stream              = aws_cloudwatch_log_stream.jenkins_nonprod_controller_log_stream.name
      jenkins_controller_port = var.jenkins_controller_port
      jenkins_agent_port      = var.jenkins_agent_port
    }
  )
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.jenkins_controller_cpu
  memory                   = var.jenkins_controller_mem
  execution_role_arn       = aws_iam_role.jenkins_nonprod_execution_role.arn
  task_role_arn            = aws_iam_role.jenkins_nonprod_execution_role.arn

  # Setting the volume to the EFS
  volume {
    name = "${var.prefix}-efs"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.nonprod_efs.id
      root_directory     = "/"
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.nonprod_efs_ap.id
        iam             = "ENABLED"
      }
    }
  }
}

# ECS service for the Jenkins controller
resource "aws_ecs_service" "jenkins" {
  name     = "jenkins"
  cluster  = aws_ecs_cluster.nonprod_controller.id
  launch_type = "FARGATE"

  task_definition = aws_ecs_task_definition.nonprod_jenkins_td.arn
  desired_count  = 1

  # Blue/green: CodeDeploy manages deployments and traffic switch. Rolling: ECS manages.
  deployment_minimum_healthy_percent = var.controller_blue_green ? 100 : 0
  deployment_maximum_percent         = var.controller_blue_green ? 200 : 100
  enable_execute_command             = true

  # Circuit breaker only with ECS rolling (not supported with CODE_DEPLOY)
  dynamic "deployment_circuit_breaker" {
    for_each = var.controller_blue_green ? [] : [1]
    content {
      enable   = true
      rollback = true
    }
  }

  dynamic "deployment_controller" {
    for_each = var.controller_blue_green ? [1] : []
    content {
      type = "CODE_DEPLOY"
    }
  }

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [aws_security_group.jenkins_nonprod_controller.id]
    assign_public_ip = var.assign_public_ip
  }

  service_registries {
    registry_arn = aws_service_discovery_service.nonprod_controller.arn
  }

  # Production target group (blue). When using CodeDeploy, green TG is used during deploy then traffic is switched.
  load_balancer {
    target_group_arn = aws_lb_target_group.nonprod_tg.arn
    container_name   = var.prefix
    container_port   = var.jenkins_controller_port
  }
}