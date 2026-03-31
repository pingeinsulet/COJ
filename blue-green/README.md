## Overview

This repo deploys **Jenkins on AWS Fargate** with a **persistent agent** and **ECS ephemeral agents**. Terraform provisions infrastructure only; Docker images are built and pushed via separate scripts or CI.

- **Environments:** `dev`, `nonprod`, `prod` (separate Terraform state and tfvars per env).
- **Terraform:** Run per environment from `environments/<env>/`. No image build inside Terraform.
- **Docker:** Use `scripts/build-controller.sh`, `scripts/build-persistent-agent.sh`, and `scripts/build-ecs-agents.sh` (or GitHub Actions) to build and push images after Terraform has been applied.

Setup is working for all three environments. To tear down while **keeping EFS and ECR** (and images), use **[scripts/destroy-preserve-efs-ecr.sh](scripts/destroy-preserve-efs-ecr.sh)**; see [docs/reliability-and-stability.md](docs/reliability-and-stability.md).

### Build, deploy, destroy (per environment)

**Go into the environment directory** and run one of three scripts (no arguments—the folder you’re in is the environment):

| Script | What it does |
|--------|---------------|
| **`./build`** | Terraform apply + build and push controller and agent images. Everything ready to deploy. |
| **`./deploy`** | Deploy to AWS (controller + persistent agent running). Run after build. |
| **`./destroy`** | Tear down the stack but **keep EFS** (plugins, config) and **ECR** (images). Bring back with `./build` (and run any import commands the script prints if state was lost; see [reliability-and-stability.md](docs/reliability-and-stability.md)). |

Example (dev):

```bash
cd environments/dev
./build     # infra + images
./deploy    # running in AWS
# later:
./destroy   # down, EFS/ECR preserved
```

Each of **`environments/dev/`**, **`environments/nonprod/`**, and **`environments/prod/`** has its own `build`, `deploy`, and `destroy` scripts.

### Promotion (dev → nonprod → prod)

To promote the same code through environments with manual gates, use the **Jenkins pipeline** in the [**promotion/**](promotion/) directory. It builds and deploys to dev, then waits for approval before nonprod, then approval before prod. See **[promotion/README.md](promotion/README.md)** for parameters, agent requirements, and how it fits with Terraform and GitHub.

### Prerequisites

- **AWS CLI** – configured with credentials that can access ECR and (for Terraform) S3/DynamoDB for state.
- **Docker** – for building and pushing images.
- **Terraform** – 1.5.x.
- **jq** – only required for the controller build when using Azure AD (optional).

### Avoid building in the wrong AWS account

Lock Terraform and build scripts to a specific AWS account (nothing is hardcoded in the repo):

- **Build scripts and Terraform:** Run once with the credentials for the account you want to allow (e.g. the profile or access key for that account):
  ```bash
  ./scripts/pin-expected-account.sh nonprod
  ```
  That writes the current account ID to `environments/<env>/.expected_aws_account_id` (gitignored). From then on, Terraform and the build scripts will only run when the current AWS identity is in that account.

- **Terraform only:** In `*.tfvars`, set `expected_aws_account_id = "<account-id>"` if you prefer to configure it there instead of using the pin script. Use the same value the pin script would write (your 12-digit account ID).

- **Build scripts only:** Set `EXPECTED_AWS_ACCOUNT_ID=<account-id>` in the environment, or use the pin script so the per-env file is used.

Leave the pin file absent and `expected_aws_account_id` / `EXPECTED_AWS_ACCOUNT_ID` unset to skip these checks.

### 1. Terraform (infrastructure only)

Run from the chosen environment directory. First time: copy `dev.tfvars.example` or `prod.tfvars.example` to `dev.tfvars` / `prod.tfvars` (for nonprod, create `nonprod.tfvars` from dev/prod or existing env). Set your backend bucket/table in `backend.tf` if needed.

```bash
cd environments/nonprod
terraform init
terraform plan -var-file=nonprod.tfvars
terraform apply -var-file=nonprod.tfvars
```

For **dev** or **prod**, use `environments/dev` or `environments/prod` and the corresponding `*.tfvars` file.

#### External controller URLs (ALB DNS)

All environments use the same design: the external Jenkins URL is the ALB DNS name (no custom hostname). **These URLs change whenever the ALB is recreated** (e.g. after `terraform destroy` and `terraform apply`). Source of truth:

```bash
cd environments/<env>   # dev, nonprod, or prod
terraform output controller_url
```

### 2. Docker (build and push images)

After Terraform apply, from the **repo root**:

```bash
# Controller (generates jenkins.yaml and pushes controller image)
./scripts/build-controller.sh nonprod

# Persistent agent
./scripts/build-persistent-agent.sh nonprod

# ECS agents (same image as persistent agent)
./scripts/build-ecs-agents.sh nonprod
```

Replace `nonprod` with `dev` or `prod` as needed. For the controller, optional Azure AD: set `AZURE_AD_SECRET_NAME` to your Secrets Manager secret name (default: `azure-ad-secrets_<env>`). Controller build requires **jq** if you use that secret.

#### Dev: controller and persistent agent (no Terraform outputs)

From repo root you can build, push, and activate without Terraform outputs. **Full redeploy (controller + agent):**

```bash
./scripts/dev/redeploy.sh
```

If the controller uses **blue/green** (`controller_blue_green = true` in tfvars), deploy the controller with CodeDeploy instead of activate: after building and pushing, run `./scripts/dev/deploy-controller-blue-green.sh`. See **[docs/blue-green-deployment.md](docs/blue-green-deployment.md)**.  
Build/deploy scripts are grouped by environment under **`scripts/dev/`**, **`scripts/nonprod/`**, **`scripts/prod/`**; see **[scripts/README.md](scripts/README.md)**.

Or step by step (build only, then push, then activate):

```bash
# Controller
./scripts/dev/build-and-push-controller.sh --build-only
./scripts/dev/push-controller.sh
./scripts/dev/activate-controller.sh

# Persistent agent
./scripts/dev/build-and-push-agent.sh --build-only
./scripts/dev/push-agent.sh
./scripts/dev/activate-persistent-agent.sh
```

See **scripts/README.md** for all script options, prerequisites, and error handling.

#### Persistent agent: JNLP secret (required)

The persistent agent connects to Jenkins via JNLP using a secret. Terraform reads it from **AWS Secrets Manager** (e.g. `jenkins/dev/persistent-agent-secret` for dev; use an env-specific secret per environment—see **nonprod/prod** in [docs/troubleshooting-persistent-agent-secret.md](docs/troubleshooting-persistent-agent-secret.md)). The secret must be JSON with key `AGENT_SECRET`:

1. In Jenkins: **Manage Jenkins → Nodes → persistent-agent** (node is defined in CasC). Copy the **secret** shown for that inbound agent.
2. Create or update the secret in AWS (replace `<secret-value>` with the value from Jenkins):
   ```bash
   aws secretsmanager create-secret --name jenkins/dev/persistent-agent-secret \
     --secret-string '{"AGENT_SECRET":"<secret-value>"}' --region us-east-2
   ```
   If the secret already exists, use `put-secret-value` instead of `create-secret`.

After changing the secret, force a new deployment of the persistent agent so the task picks it up (e.g. `./scripts/dev/activate-persistent-agent.sh`).

**If the persistent agent fails with EFS mount timeout** (e.g. `mount.nfs4: mount system call failed`), see **[docs/troubleshooting-efs-persistent-agent.md](docs/troubleshooting-efs-persistent-agent.md)**. In short: run `terraform apply` in that environment so the EFS security group allows NFS from the agents and VPC, then force a new deployment (e.g. `./scripts/dev/activate-persistent-agent.sh` or the nonprod script).

For **reliability and stability** (circuit breaker, health checks, zero-overlap deploy, alarms, backups), see **[docs/reliability-and-stability.md](docs/reliability-and-stability.md)**.

### 3. GitHub Actions

- **Terraform:** `.github/workflows/terraform.yml` – workflow_dispatch with inputs: environment (dev/nonprod/prod), action (plan/apply/destroy). Set secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and optionally `TF_STATE_BUCKET`, `TF_LOCK_TABLE`.
- **Build Controller:** `.github/workflows/build-controller.yml` – workflow_dispatch, select environment.
- **Build Persistent Agent:** `.github/workflows/build-persistent-agent.yml` – workflow_dispatch, select environment.
- **Build ECS Agents:** `.github/workflows/build-ecs-agents.yml` – workflow_dispatch, select environment.

---

## Run Instructions for Serverless Jenkins pipelines (legacy / reference)

Clone this repo (or your GitHub fork). To update agents, modify the **Dockerfile** under **docker/jenkins_agent**. To update the controller, modify **docker/jenkins_controller/Dockerfile** and **plugins.txt** as needed.

After infrastructure is applied, use the scripts above or the GitHub Actions workflows to build and push images. 

## The following explains the complete repository: 

**Dockerfile:** Builds a Jenkins inbound agent container image with jq, Git, and AWS CLI, and a custom entrypoint to start the agent and manage config.

**jenkins-agent-entrypoint.sh:** This script serves as a custom entrypoint for a Jenkins agent Docker container, configuring host file entries, setting up AWS credentials, adjusting permissions, and transitioning to the Jenkins user to start the agent process.

## Sub folder name: 

### jenkins_controller

**docker-entrypoint.sh**: This script acts as a custom entrypoint for a Jenkins Docker container, managing host file entries, fixing permissions for the Jenkins home directory, and switching to the Jenkins user to start the Jenkins server.

**Dockerfile**: This Dockerfile script sets up a Jenkins server with JDK 17, pre-configures it for integration with Azure Active Directory, installs necessary plugins and configurations, and uses a custom entrypoint script to manage startup processes.

**jenkins.yaml.tftpl:** This YAML configuration script sets up a Jenkins instance with specific settings for security, agent protocols, authorization strategy using Azure AD, and integration with AWS ECS for agent deployment, configuring various aspects like networking, logging, and EFS mounts.

**plugins.txt**: define plugins that want to install

### jenkins-ecs

**cloud_map.tf:** This Terraform script configures a private DNS namespace and a DNS service within a specified VPC to manage DNS records for a Jenkins controller, enhancing service discovery and network management.

**cloudwatch.tf:**This Terraform script creates a CloudWatch log group and separate log streams for both the Jenkins controller and Jenkins agents, facilitating centralized logging and monitoring of Jenkins operations on AWS.

**ecr.tf:** This Terraform script creates AWS ECR repositories for Jenkins controller and agent images and generates the Jenkins configuration file (jenkins_*.yaml) from the template. Image build and push are done separately via scripts or CI, not by Terraform.

**ecs.tf:** This Terraform script configures ECS clusters, capacity providers, task definitions, and services for both Jenkins controllers and agents on AWS, integrating essential components like EFS for storage and CloudMap for service discovery to manage and scale Jenkins workloads efficiently.

**efs.tf:** This Terraform script sets up an encrypted Amazon EFS file system with mount targets in private subnets and an access point configured for Jenkins, facilitating secure and scalable storage integration for Jenkins data.

**elb.tf:** Configures the Application Load Balancer (ALB) for the controller (internal or internet-facing per `alb_internal`), with HTTP/HTTPS listeners, security settings, and target groups..

**iam.tf:** This Terraform script establishes IAM roles and policies for Jenkins, granting it permissions to manage ECS tasks, interact with S3 buckets, handle secrets via Secrets Manager, and facilitate SSM session management for secure operations on AWS

**route53.tf:** This Terraform script creates an AWS Route 53 DNS A record that aliases to an Application Load Balancer's DNS name, enabling domain name resolution and traffic routing to the ALB.

**security_groups.tf:** This Terraform script configures various AWS security groups to manage network access for Jenkins infrastructure components, including the Application Load Balancer, Jenkins controllers, Jenkins agents, and the Jenkins controller's EFS storage, ensuring secure and specific traffic flow within the VPC.

**variables.tf:** This Terraform script defines a set of variables to configure AWS infrastructure for a Jenkins deployment, including naming conventions, network settings, computational resources, and security components, ensuring a structured and scalable environment setup.

### sub folder name:

**task-definitions:** jenkins.tftpl: This script defines a JSON configuration for a Docker container, specifically tailored for a Jenkins deployment, configuring aspects like CPU and memory resources, port mappings, EFS volume mounts, logging with AWS CloudWatch, and environmental settings for the JVM.

### Remaining files

- **environments/** – Per-environment Terraform: `dev`, `nonprod`, `prod`. Each has `main.tf`, `backend.tf`, `provider.tf`, `variables.tf`, `outputs.tf`, and `*.tfvars` (or `*.tfvars.example`). **environments/bootstrap/** – One-time setup for S3/DynamoDB state backend.
- **scripts/** – `build-controller.sh`, `build-persistent-agent.sh`, `build-ecs-agents.sh`, `common.sh`, `destroy-preserve-efs-ecr.sh`; env-specific under `scripts/dev/`, `scripts/nonprod/`, `scripts/prod/`.
- **.github/workflows/** – GitHub Actions: `terraform.yml`, `build-controller.yml`, `build-persistent-agent.yml`, `build-ecs-agents.yml`.
- **main.tf** (root) – Note to run Terraform from `environments/<env>/`, not repo root.
