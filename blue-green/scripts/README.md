# Scripts

Scripts for building, pushing, and deploying Jenkins controller and agent images.  
Run all commands from the **repository root** unless noted.

---

## Script organization: folders by environment (not branches)

Build and deploy scripts are grouped by environment under **`scripts/dev/`**, **`scripts/nonprod/`**, and **`scripts/prod/`**.

- **Why folders, not repo branches?** Using a branch per environment (e.g. `dev` branch = dev scripts only) would duplicate script logic across branches and make fixes and features harder to keep in sync. One branch holds all three folders; you run the path that matches the environment you’re targeting (e.g. `./scripts/dev/build-and-push-controller.sh` or `./scripts/prod/build-and-push-controller.sh`). No branch switching.
- **Dev** scripts in `scripts/dev/` can use hardcoded account/region/names for quick local use; **nonprod** and **prod** scripts in `scripts/nonprod/` and `scripts/prod/` are thin wrappers that call shared, parameterized scripts with the right environment so Terraform outputs drive cluster names, ECR URIs, etc.

| Location | Use when |
|----------|----------|
| `scripts/dev/` | Building, pushing, or deploying to **dev** (fixed account/region). |
| `scripts/nonprod/` | Building, pushing, or deploying to **nonprod** (Terraform outputs). |
| `scripts/prod/` | Building, pushing, or deploying to **prod** (Terraform outputs). |
| `scripts/*.sh` (root) | Shared, env-agnostic scripts (e.g. `build-controller.sh <env>`, `common.sh`). |

### Destroy while preserving EFS and ECR

**`./scripts/destroy-preserve-efs-ecr.sh <env>`** (dev, nonprod, or prod) tears down the stack but **leaves EFS** (job files, workspaces) and **ECR repos** (controller/agent images) in AWS. Run from repo root. After destroy, the script prints the `terraform import` and `terraform apply` commands needed to bring the stack back **without repushing images**. See [docs/reliability-and-stability.md](../docs/reliability-and-stability.md#efs).

---

## Prerequisites

| Script type      | Docker | AWS CLI | Terraform | jq   |
|------------------|--------|--------|-----------|------|
| Dev build/push   | Yes    | Yes*   | No        | No   |
| Dev activate     | No     | Yes    | No        | No   |
| Env build (dev/nonprod/prod) | Yes | Yes | Yes (applied) | Yes** |

\* For push: AWS credentials for account `114039064573` (dev), region `us-east-2`.  
\** Only for controller build when using Azure AD secret.

- **Docker**: Engine, Buildx. Your user must be able to run `docker` (e.g. in `docker` group).
- **AWS**: `aws configure` or `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`; account must match the target environment.

---

## Dev (`scripts/dev/`)

Dev uses fixed ECR URIs and ECS cluster/service names. No Terraform outputs required.

### Controller

| Script | Purpose |
|--------|--------|
| `scripts/dev/build-and-push-controller.sh [--build-only]` | Build controller image; without `--build-only`, also logs in to ECR, tags, and pushes. |
| `scripts/dev/push-controller.sh` | Push existing `jenkins-controller:latest` to dev ECR (no build). |
| `scripts/dev/activate-controller.sh` | Force ECS rolling deployment (use when **controller_blue_green** is false). |
| `scripts/dev/deploy-controller-blue-green.sh` | CodeDeploy blue/green with zero overlap (scale to 0, then deploy). Use when **controller_blue_green** is true. Build and push first, then run this. See [Blue/Green Deployment](../docs/blue-green-deployment.md#zero-overlap-deployment-recommended-with-shared-efs). |
| `scripts/dev/wait-and-apply-blue-green.sh` | After enabling blue/green, waits for the ECS service to finish draining, then runs `terraform apply` in dev. |

### Agent (persistent + ECS ephemeral)

| Script | Purpose |
|--------|--------|
| `scripts/dev/build-and-push-agent.sh [--build-only]` | Build agent image; without `--build-only`, also push to dev ECR. |
| `scripts/dev/push-agent.sh` | Push existing `jenkins-agent:latest` to dev ECR. |
| `scripts/dev/activate-persistent-agent.sh` | Force ECS to deploy current persistent agent `:latest`. |

### Full dev redeploy

```bash
./scripts/dev/redeploy.sh
```

Builds controller → pushes → activates; builds agent → pushes → activates. Any step that fails will stop the script.

---

## Nonprod (`scripts/nonprod/`) and Prod (`scripts/prod/`)

| Script | Purpose |
|--------|--------|
| `scripts/nonprod/build-and-push-controller.sh` | Same as `./scripts/build-controller.sh nonprod`. |
| `scripts/nonprod/build-and-push-agent.sh` | Same as `./scripts/build-persistent-agent.sh nonprod`. |
| `scripts/nonprod/deploy-controller-blue-green.sh` | Zero-overlap controller deploy (scale to 0, wait, then deploy). Same behavior as dev. |
| `scripts/nonprod/activate-persistent-agent.sh` | Force ECS to deploy current persistent agent `:latest` for nonprod. |
| `scripts/prod/build-and-push-controller.sh` | Same as `./scripts/build-controller.sh prod`. |
| `scripts/prod/build-and-push-agent.sh` | Same as `./scripts/build-persistent-agent.sh prod`. |
| `scripts/prod/deploy-controller-blue-green.sh` | Zero-overlap controller deploy (scale to 0, wait, then deploy). Same behavior as dev. |
| `scripts/prod/activate-persistent-agent.sh` | Force ECS to deploy current persistent agent `:latest` for prod. |

All three environments use the same deploy flow: **zero-overlap** controller (scale to 0, then deploy) then activate persistent agent. Run from the env directory: `./deploy`.

---

## Shared env-based scripts (root)

These scripts use Terraform outputs from `environments/<env>/`. Run `terraform init` and `terraform apply -var-file=<env>.tfvars` in that directory first.

| Script | Purpose |
|--------|--------|
| `build-controller.sh <env>` | Build controller (copies generated `jenkins.yaml`), tag, push to env ECR. |
| `build-persistent-agent.sh <env>` | Build agent image, tag, push. |
| `build-ecs-agents.sh <env>` | Same as persistent agent (same image). |

Optional: set `AZURE_AD_SECRET_NAME` for controller AAD; `require_jq` applies when using that secret.

---

## Other

| Script | Purpose |
|--------|--------|
| `install-docker-ubuntu.sh` | Install Docker CE (engine, CLI, containerd, buildx, compose) on Ubuntu. Run with `sudo bash scripts/install-docker-ubuntu.sh`. |
| `common.sh` | Shared helpers (do not run directly). Used by env-based build scripts. |
| `pin-expected-account.sh <env>` | Write current AWS account ID to `environments/<env>/.expected_aws_account_id` so builds only run in that account. |

---

## Error handling

- Scripts use `set -euo pipefail`: any failing command or use of unset variable exits the script.
- Dev scripts check for `docker` (and `aws` when pushing) and exit with a clear message if missing.
- Push scripts require the corresponding image to exist locally (e.g. `jenkins-controller:latest`); otherwise `docker tag` fails with a clear error.
- Activate scripts only trigger a new ECS deployment; they do not wait for stability. Use AWS Console or `aws ecs describe-services` to confirm.

---

## Persistent agent secret

The persistent agent connects via JNLP using a secret from AWS Secrets Manager. The secret must be JSON: `{"AGENT_SECRET":"<value>"}`. Get the value from **the same environment’s** Jenkins: **Manage Jenkins → Nodes → persistent-agent**.

- **Dev:** `jenkins_agent_secret_name = "jenkins/dev/persistent-agent-secret"`. Create/update that secret with the value from the dev controller’s persistent-agent node.
- **Nonprod / prod:** Use an environment-specific secret (e.g. `jenkins/nonprod/persistent-agent-secret`) and the value from that environment’s Jenkins. If you see "incorrect secret" or "Authorization failure" in logs, see **docs/troubleshooting-persistent-agent-secret.md**.

Example (dev):

```bash
aws secretsmanager create-secret --name jenkins/dev/persistent-agent-secret \
  --secret-string '{"AGENT_SECRET":"<paste-from-jenkins>"}' --region us-east-2
# If secret exists:
aws secretsmanager put-secret-value --secret-id jenkins/dev/persistent-agent-secret \
  --secret-string '{"AGENT_SECRET":"<paste-from-jenkins>"}' --region us-east-2
```

After changing the secret, force a new deployment so new tasks pick it up: `./scripts/dev/activate-persistent-agent.sh` or `./scripts/nonprod/activate-persistent-agent.sh`, or for prod use `aws ecs update-service ... --force-new-deployment` with the persistent-agent service.
