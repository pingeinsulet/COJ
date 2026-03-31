# Same account as dev/nonprod for build. Change aws_account_id and resources to use a different account.
aws_account_id             = "114039064573"

aws_region                 = "us-east-2"
prefix                     = "jenkins-blue-green-prod"
vpc_id                     = "vpc-0a8401a23d48a4bae"
private_subnets            = ["subnet-06e158d9e205a9588", "subnet-04e35976121efcd63", "subnet-06ea6dd1d4590f251"]
public_subnets             = ["subnet-06e158d9e205a9588", "subnet-04e35976121efcd63", "subnet-06ea6dd1d4590f251"]
jenkins_controller_cpu     = "4096"
jenkins_controller_mem     = "8192"
assign_public_ip           = true
alb_internal               = false
alb_acm_certificate_arn    = ""
route53_zone_id            = ""
route53_alias_name         = ""
# Must match the secret for the *prod* controller's persistent-agent node.
# Create in Secrets Manager with: {"AGENT_SECRET":"<value from Manage Jenkins → Nodes → persistent-agent>"}
# See docs/troubleshooting-persistent-agent-secret.md if you see "incorrect secret" in logs.
jenkins_agent_secret_name  = "jenkins/prod/persistent-agent-secret"
jenkins_webserver_hostname = "jenkins.prod.insulet.com"
