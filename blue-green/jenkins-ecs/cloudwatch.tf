# CloudWatch log group for Jenkins
resource "aws_cloudwatch_log_group" "jenkins_nonprod_logs" {
  name              = "/ecs/${var.prefix}"
  retention_in_days  = var.cloudwatch_log_retention_days

  tags = {
    Name = "${var.prefix}-logs"
  }
}

# log stream for the Jenkins controller
resource "aws_cloudwatch_log_stream" "jenkins_nonprod_controller_log_stream" {
  name           = "${var.prefix}-controller"
  log_group_name = aws_cloudwatch_log_group.jenkins_nonprod_logs.name
}

# log stream for the Jenkins agents
resource "aws_cloudwatch_log_stream" "jenkins_nonprod_agent_log_stream" {
  name           = "${var.prefix}-agent"
  log_group_name = aws_cloudwatch_log_group.jenkins_nonprod_logs.name
}