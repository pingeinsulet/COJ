# ALB
resource "aws_lb" "nonprod_alb" {
  name               = "${var.prefix}-alb"
  internal           = var.alb_internal
  load_balancer_type = "application"
  # Attaching the jenkins-alb security group
  security_groups = [aws_security_group.jenkins_nonprod_alb.id]
  # Placing the ALB in all the public subnets
  subnets = var.public_subnets

  tags = {
    Name = "${var.prefix}-alb"
  }
}

# Load balancer target group - Blue (production traffic when using blue/green)
resource "aws_lb_target_group" "nonprod_tg" {
  name        = "${var.prefix}-tg"
  target_type = "ip"
  port        = tonumber(var.jenkins_controller_port)
  protocol    = "HTTP"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = "/login"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.prefix}-tg"
  }
}

# Green target group for blue/green deployments (only used when controller_blue_green = true)
resource "aws_lb_target_group" "nonprod_tg_green" {
  count       = var.controller_blue_green ? 1 : 0
  name        = "${var.prefix}-tg-green"
  target_type = "ip"
  port        = tonumber(var.jenkins_controller_port)
  protocol    = "HTTP"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = "/login"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.prefix}-tg-green"
  }
}

# ALB Listener HTTP: redirect to HTTPS when cert is set
resource "aws_lb_listener" "nonprod_http_redirect" {
  count             = var.alb_acm_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.nonprod_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ALB Listener HTTP: forward to Jenkins when no cert (e.g. dev)
resource "aws_lb_listener" "nonprod_http_forward" {
  count             = var.alb_acm_certificate_arn == "" ? 1 : 0
  load_balancer_arn = aws_lb.nonprod_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nonprod_tg.arn
  }
}

# ALB Listener HTTPS (only when cert is provided)
resource "aws_lb_listener" "nonprod_https" {
  count             = var.alb_acm_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.nonprod_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-Res-2019-08"
  certificate_arn   = var.alb_acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nonprod_tg.arn
  }
}
