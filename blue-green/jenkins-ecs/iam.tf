# AWS managed policy: AmazonECSTaskExecutionRolePolicy
data "aws_iam_policy" "aws_ecs_task_execution_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# EFS client permissions for IAM-authorized mounts (controller and persistent agent)
data "aws_iam_policy" "efs_client_read_write" {
  arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientReadWriteAccess"
}

# AWS managed policy: SecretsManagerReadWrite
data "aws_iam_policy" "aws_secret_manager_policy" {
  arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

# AWS managed policy: AWSCloudFormationFullAccess
data "aws_iam_policy" "aws_cloudformation_full_access" {
  arn = "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess"
}

# AWS managed policy: AmazonSNSFullAccess
data "aws_iam_policy" "aws_sns_full_access" {
  arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

# AWS managed policy: AmazonDynamoDBFullAccess
data "aws_iam_policy" "aws_dynamodb_full_access" {
  arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# AWS managed policy: AWSLambda_FullAccess
data "aws_iam_policy" "aws_lambda_full_access" {
  arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
}

# AWS managed policy: AmazonEventBridgeFullAccess
data "aws_iam_policy" "aws_eventbridge_full_access" {
  arn = "arn:aws:iam::aws:policy/AmazonEventBridgeFullAccess"
}

# IAM policy that provides Jenkins with the necessary permissions, including S3 bucket access
resource "aws_iam_policy" "jenkins_nonprod_policy" {
  name   = "${var.prefix}-policy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "ECSPermissions",
        "Effect": "Allow",
        "Action": [
          "ecs:ListClusters",
          "ecs:ListTaskDefinitions",
          "ecs:ListContainerInstances",
          "ecs:RunTask",
          "ecs:StopTask",
          "ecs:DescribeTasks",
          "ecs:DescribeContainerInstances",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:ListTagsForResource",
          "iam:GetRole",
          "iam:PassRole"
        ],
        "Resource": "*"
      },
      {
        "Sid": "S3BucketAccess",
        "Effect": "Allow",
        "Action": [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        "Resource": [
          "arn:aws:s3:::auto-deployment-results.com",
          "arn:aws:s3:::auto-deployment-results.com/*"
        ]
      },
      {
        "Sid": "SSMSessionManagerPermissions",
        "Effect": "Allow",
        "Action": [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        "Resource": "*"
      }
    ]
  })
}

# Jenkins Execution Role
resource "aws_iam_role" "jenkins_nonprod_execution_role" {
  name = "${var.prefix}-execution-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = [
    data.aws_iam_policy.aws_ecs_task_execution_policy.arn,
    data.aws_iam_policy.efs_client_read_write.arn,
    data.aws_iam_policy.aws_secret_manager_policy.arn,
    data.aws_iam_policy.aws_cloudformation_full_access.arn,
    data.aws_iam_policy.aws_sns_full_access.arn,
    data.aws_iam_policy.aws_dynamodb_full_access.arn,
    data.aws_iam_policy.aws_lambda_full_access.arn,
    data.aws_iam_policy.aws_eventbridge_full_access.arn,
    aws_iam_policy.jenkins_nonprod_policy.arn
  ]
}