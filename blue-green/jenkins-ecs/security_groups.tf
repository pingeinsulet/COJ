# SG for the Jenkins ALB
resource "aws_security_group" "jenkins_nonprod_alb" {
  name        = "${var.prefix}-alb-sg"
  description = "Security group for the ALB that points to the Jenkins master"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow all traffic through port 80"
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow all traffic through port 443"
    from_port   = "443"
    to_port     = "443"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-jenkins-alb"
  }
}

# SG for the Jenkins agents
resource "aws_security_group" "jenkins_nonprod_agents" {
  name        = "${var.prefix}-agents-sg"
  description = "Security group for the Jenkins agents"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound traffic"
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-jenkins-agents"
  }
}

# SG for the Jenkins controller
resource "aws_security_group" "jenkins_nonprod_controller" {
  name        = "${var.prefix}-controller-sg"
  description = "Security group for the Jenkins master"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow traffic from the ALB"
    from_port       = var.jenkins_controller_port
    to_port         = var.jenkins_controller_port
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_nonprod_alb.id]
  }

  ingress {
    description     = "Allow traffic from the Jenkins agents over JNLP"
    from_port       = var.jenkins_agent_port
    to_port         = var.jenkins_agent_port
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_nonprod_agents.id]
  }

  ingress {
    description     = "Allow traffic from the Jenkins agents"
    from_port       = var.jenkins_controller_port
    to_port         = var.jenkins_controller_port
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_nonprod_agents.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-jenkins-controller"
  }
}

# SG for the Jenkins controller EFS
resource "aws_security_group" "jenkins_nonprod_efs" {
  name        = "${var.prefix}-efs-sg"
  description = "Security group for the EFS of the Jenkins controller"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow traffic from the Jenkins controller"
    from_port       = "2049"
    to_port         = "2049"
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_nonprod_controller.id]
  }

  ingress {
    description     = "Allow traffic from the Jenkins agents (persistent agent mounts EFS)"
    from_port       = "2049"
    to_port         = "2049"
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_nonprod_agents.id]
  }

  ingress {
    description = "Allow NFS from VPC (covers all tasks in this VPC, e.g. persistent agent)"
    from_port   = "2049"
    to_port     = "2049"
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-jenkins-efs"
  }
}