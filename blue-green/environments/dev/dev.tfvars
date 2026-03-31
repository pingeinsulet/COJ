# Dev. Change aws_account_id to deploy to a different account; then update vpc_id, subnets, etc.
# aws_account_id            = "114039064573"

# Dev: default VPC us-east-2, HTTP-only public ALB, no Route53
aws_region                = "us-east-2"
prefix                    = "jenkins-blue-green-dev"
vpc_id                    = "vpc-0a8401a23d48a4bae"
private_subnets           = ["subnet-06e158d9e205a9588", "subnet-04e35976121efcd63", "subnet-06ea6dd1d4590f251"]
public_subnets            = ["subnet-06e158d9e205a9588", "subnet-04e35976121efcd63", "subnet-06ea6dd1d4590f251"]
jenkins_controller_cpu    = "2048"
jenkins_controller_mem    = "4096"
assign_public_ip          = true
alb_internal              = false
alb_acm_certificate_arn   = ""
route53_zone_id           = ""
route53_alias_name        = ""
jenkins_agent_secret_name = "jenkins/dev/persistent-agent-secret"
controller_blue_green     = true
jenkins_webserver_hostname = "jenkins.dev.insulet.com"
