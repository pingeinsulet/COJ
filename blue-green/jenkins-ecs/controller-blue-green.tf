# Blue/green deployment for Jenkins controller (CodeDeploy + two target groups).
# When controller_blue_green is true, deploy new task revisions to the inactive target group,
# then switch ALB traffic. Rollback by switching traffic back.

# CodeDeploy application (ECS)
resource "aws_codedeploy_app" "jenkins_controller" {
  count            = var.controller_blue_green ? 1 : 0
  name             = "${var.prefix}-controller"
  compute_platform = "ECS"

  tags = {
    Name = "${var.prefix}-controller"
  }
}

# IAM role for CodeDeploy to perform ECS blue/green (update listener, manage task sets)
resource "aws_iam_role" "codedeploy_ecs" {
  count = var.controller_blue_green ? 1 : 0

  name = "${var.prefix}-codedeploy-ecs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })
}

# CodeDeploy needs to modify the ALB listener to switch traffic between blue and green target groups
resource "aws_iam_role_policy" "codedeploy_ecs_alb" {
  count = var.controller_blue_green ? 1 : 0

  name   = "alb-listener-and-ecs"
  role   = aws_iam_role.codedeploy_ecs[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ALB"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DeleteRule",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:RemoveTags",
          "elasticloadbalancing:SetRulePriorities"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECS"
        Effect = "Allow"
        Action = [
          "ecs:CreateTaskSet",
          "ecs:DeleteTaskSet",
          "ecs:DescribeClusters",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTaskSets",
          "ecs:UpdateServicePrimaryTaskSet",
          "ecs:UpdateService"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassRole"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          aws_iam_role.jenkins_nonprod_execution_role.arn
        ]
        Condition = {
          StringLike = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Deployment group: links ECS service, blue/green target groups, and ALB listener(s)
resource "aws_codedeploy_deployment_group" "jenkins_controller" {
  count = var.controller_blue_green ? 1 : 0

  app_name               = aws_codedeploy_app.jenkins_controller[0].name
  deployment_group_name  = "${var.prefix}-controller"
  service_role_arn       = aws_iam_role.codedeploy_ecs[0].arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  ecs_service {
    cluster_name = aws_ecs_cluster.nonprod_controller.name
    service_name = aws_ecs_service.jenkins.name
  }

  load_balancer_info {
    target_group_pair_info {
      target_group {
        name = aws_lb_target_group.nonprod_tg.name
      }
      target_group {
        name = aws_lb_target_group.nonprod_tg_green[0].name
      }
      prod_traffic_route {
        listener_arns = concat(
          aws_lb_listener.nonprod_http_forward[*].arn,
          aws_lb_listener.nonprod_https[*].arn
        )
      }
    }
  }

  blue_green_deployment_config {
    deployment_ready_option {
      # Don't switch traffic if new tasks aren't ready in time (more stable)
      action_on_timeout  = "STOP_DEPLOYMENT"
      wait_time_in_minutes = 60
    }
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type    = "BLUE_GREEN"
  }

  tags = {
    Name = "${var.prefix}-controller"
  }
}
