# Reliability and Stability

Improvements and practices to keep Jenkins on ECS stable and recoverable.

## Implemented in this repo

### Deployment

- **Deployment circuit breaker** (ECS): If a deployment causes the service to fall below the minimum healthy percent, ECS rolls the deployment back automatically. Reduces risk of leaving the service with no healthy tasks.
- **CodeDeploy: stop on timeout**: Blue/green is configured with `action_on_timeout = STOP_DEPLOYMENT`. If the new (green) tasks don’t become ready in time, CodeDeploy does **not** switch traffic; the deployment stops and the current (blue) set keeps serving. Prevents switching to an unhealthy version.
- **Zero-overlap deploy**: The dev blue/green script (`./scripts/dev/deploy-controller-blue-green.sh`) scales to 0 first, then deploys, so only one controller uses EFS at a time. See [Blue/Green Deployment](blue-green-deployment.md#zero-overlap-deployment-recommended-with-shared-efs).

### Controller task

- **Container health check**: The controller task definition includes an ECS health check (`/login` via curl every 30s, 5s timeout, 3 retries, 300s start period). Unhealthy containers can be replaced by ECS. The controller image includes `curl` for this check.
- **Graceful shutdown**: Container `stopTimeout` is 120 seconds so Jenkins has time to shut down and release EFS before being killed.

### Observability and cost

- **Log retention**: CloudWatch log group uses `cloudwatch_log_retention_days` (default 30). Set to `0` in your tfvars to retain logs indefinitely. Reduces cost and avoids unbounded growth.

---

## Optional improvements you can add

### Alarms and notifications

- **Controller down**: CloudWatch alarm when ECS service `RunningCount` is 0 for the controller cluster/service. Notify via SNS (email, PagerDuty, etc.).
- **CodeDeploy failure**: Alarm on CodeDeploy deployment status `Failed` or `Stopped` for the controller deployment group.
- **EFS**: Alarms on `ClientConnections`, `DataRead/WriteLatency`, or `PermittedThroughput` (if using provisioned throughput) to spot connectivity or performance issues.

### EFS

- **EFS never deleted or overwritten**: The EFS file system, its mount targets, and access point use `lifecycle { prevent_destroy = true }`. No script in this repo may delete EFS or wipe its contents. The destroy script removes EFS from state before `terraform destroy` and aborts if any EFS resource would still be destroyed. See **jenkins-ecs/efs.tf** and **scripts/destroy-preserve-efs-ecr.sh**.
- **Preserved on destroy**: ECR repositories (controller and agent) also use `prevent_destroy`. To destroy the rest of the stack while **leaving EFS and ECR (and images) in place**, use **`./scripts/destroy-preserve-efs-ecr.sh <env>`** (dev, nonprod, or prod). That script scales ECS to 0, removes EFS and ECR from state, verifies the destroy plan does not include EFS, then runs `terraform destroy`. To bring the stack back, run the import commands the script prints, then `terraform apply`. No need to repush controller or agent images.
- **Backup**: Enable [AWS Backup](https://docs.aws.amazon.com/efs/latest/ug/awsbackup.html) for the EFS file system (or periodic snapshots) so you can restore Jenkins home if needed.
- **Lifecycle**: Use EFS lifecycle management to move old/infrequent data to Infrequent Access to reduce cost; be careful not to move active job workspaces.
- **Throughput**: If you see throttling or slow I/O, consider provisioned throughput or increase burst credit balance (larger file system usage builds credits).

### Resource sizing

- **Controller CPU/memory**: If the controller is OOM-killed or slow under load, increase `jenkins_controller_cpu` and `jenkins_controller_mem` in your tfvars. Monitor CloudWatch metrics for the task.
- **Agent**: Same for the persistent agent task definition if builds or workspace usage grow.

### Security and hygiene

- **Secrets**: Keep agent secrets and any controller credentials in Secrets Manager (or Parameter Store); reference them in the task definition; avoid env vars for secrets where possible.
- **Image scanning**: Use ECR image scanning and block deployments when critical vulnerabilities are found.
- **Terraform**: Use remote state (e.g. S3 + DynamoDB lock) and consider `expected_aws_account_id` to avoid applying to the wrong account.

### Runbooks

- **Controller unreachable**: Check ECS service (desired vs running count), target group health, ALB, and security groups. Check CloudWatch logs for the controller task.
- **Deploy failed**: Check CodeDeploy deployment history and ECS events; inspect controller logs for startup errors (e.g. EFS mount, plugin, or config).
- **EFS timeout / agent disconnect**: See [Troubleshooting EFS and persistent agent](troubleshooting-efs-persistent-agent.md).

---

## Variable reference (reliability-related)

| Variable | Default | Purpose |
|----------|---------|---------|
| `cloudwatch_log_retention_days` | 30 | Retain Jenkins ECS logs in CloudWatch (0 = never expire). |
| `controller_blue_green` | false | Use CodeDeploy blue/green; enables circuit breaker behavior and second target group. |
| `expected_aws_account_id` | "" | If set, Terraform apply fails when run in a different AWS account. |
