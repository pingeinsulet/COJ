# Persistent Jenkins Agent ECS Service
# This creates an always-on agent that uses the SAME label as ephemeral agents
# The agent connects via JNLP (not managed by ECS plugin)
#
# NOTE: Agents mount EFS for workspace persistence. If EFS contains too many files,
# operations like 'find' can timeout. Consider EFS lifecycle policies or cleanup jobs.
#
# SECURITY: Agent secret is stored in AWS Secrets Manager for secure handling.
# Set jenkins_agent_secret_name variable to the secret name in Secrets Manager.

# Fetch agent secret from AWS Secrets Manager (if secret name is provided)
# Note: Secret must exist in Secrets Manager with a value before running terraform apply
# If secret doesn't exist yet, set jenkins_agent_secret_name to "" in main.tf
data "aws_secretsmanager_secret_version" "jenkins_agent_secret" {
  count     = var.jenkins_agent_secret_name != "" ? 1 : 0
  secret_id = var.jenkins_agent_secret_name
  
  # This will fail if secret doesn't exist or has no value
  # To avoid this error, either:
  # 1. Set jenkins_agent_secret_name = "" in main.tf (temporary)
  # 2. Create the secret in Secrets Manager first with a placeholder value
}

# Task definition for persistent agent (image must be built and pushed separately)
resource "aws_ecs_task_definition" "persistent_agent" {
  family = "${var.prefix}-persistent-agent"
  
  container_definitions = jsonencode([{
    name      = "persistent-agent"
    image     = "${aws_ecr_repository.jenkins_nonprod_agent_repo.repository_url}:latest"
    cpu       = 1024
    memory    = 4096
    essential = true
    
    environment = [
      {
        name  = "JENKINS_URL"
        # Use service discovery DNS (same as ephemeral agents use)
        # Format: <prefix>.controller.dns
        value = "http://${aws_service_discovery_service.nonprod_controller.name}.${aws_service_discovery_private_dns_namespace.nonprod_controller.name}:${var.jenkins_controller_port}"
      },
      {
        name  = "JENKINS_AGENT_PORT"
        value = var.jenkins_agent_port
      }
      # Note: Agent name is specified in command arguments, not as environment variable
      # to avoid "AGENT_NAME defined twice" error
    ]
    
    # JNLP connection command
    # Format: java -jar agent.jar -url <jenkins_url> -workDir <dir> -name <agent_name> -secret <secret>
    # Agent name must match the node name in Jenkins (persistent-agent)
    # 
    # SECURITY: Secret is retrieved from AWS Secrets Manager
    # If jenkins_agent_secret_name is set, use secret from Secrets Manager
    # IMPORTANT: Secret is REQUIRED for JNLP connection - agent will fail without it
    command = var.jenkins_agent_secret_name != "" ? [
      "-url", "http://${aws_service_discovery_service.nonprod_controller.name}.${aws_service_discovery_private_dns_namespace.nonprod_controller.name}:${var.jenkins_controller_port}",
      "-workDir", "/home/jenkins/agent",
      "-name", "persistent-agent",
      "-secret", jsondecode(data.aws_secretsmanager_secret_version.jenkins_agent_secret[0].secret_string)["AGENT_SECRET"]
    ] : [
      # ERROR: Secret is required but not configured
      # Set jenkins_agent_secret_name in main.tf and ensure secret exists in Secrets Manager
      # The agent will fail to connect without a secret
      "-url", "http://${aws_service_discovery_service.nonprod_controller.name}.${aws_service_discovery_private_dns_namespace.nonprod_controller.name}:${var.jenkins_controller_port}",
      "-workDir", "/home/jenkins/agent",
      "-name", "persistent-agent"
      # Missing -secret parameter - connection will fail
    ]
    
    mountPoints = [{
      containerPath = "/var/jenkins_home"
      sourceVolume  = "${var.prefix}-efs"
      readOnly      = false
    }]
    
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.jenkins_nonprod_logs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "persistent-agent"
      }
    }
  }])
  
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = 1024
  memory                  = 4096
  execution_role_arn      = aws_iam_role.jenkins_nonprod_execution_role.arn
  task_role_arn           = aws_iam_role.jenkins_nonprod_execution_role.arn
  
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

# ECS Service for persistent agent (always running)
# Deployment is lenient so transient failures (e.g. ECR pull timeout, network blip) are non-fatal:
# - minimum_healthy_percent = 0 allows 0 running during deploy so ECS keeps retrying instead of failing.
# - No deployment circuit breaker so failed task starts do not roll back the service.
resource "aws_ecs_service" "persistent_agent" {
  name            = "${var.prefix}-persistent-agent"
  cluster         = aws_ecs_cluster.nonprod_agents.id
  task_definition = aws_ecs_task_definition.persistent_agent.arn
  launch_type     = "FARGATE"
  
  desired_count                       = 1  # Always keep 1 agent running
  deployment_minimum_healthy_percent  = 0  # Non-fatal: allow retries on ECR pull / init failures
  deployment_maximum_percent          = 200
  
  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [aws_security_group.jenkins_nonprod_agents.id]
    assign_public_ip = var.assign_public_ip
  }
}
