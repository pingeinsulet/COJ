# Blue/Green Deployment (Jenkins Controller)

When **controller_blue_green** is enabled, the Jenkins controller uses **AWS CodeDeploy** for blue/green deployments instead of ECS rolling updates.

## How it works

- **Two target groups**: Blue (production traffic) and Green (inactive). The ALB listener forwards to one of them.
- **Deploy**: New task definition revision is deployed to the **inactive** target group. New tasks start and run health checks.
- **Switch**: After the new tasks are healthy, CodeDeploy switches the listener to the new target group. Traffic moves to the new version.
- **Cleanup**: Old tasks (previous target group) are terminated after a short wait (configurable in Terraform).

## Why you see two deployment IDs

- **In ECS** (Service → Deployments): You see two rows because blue/green uses two **task sets**—one **PRIMARY** (currently receiving traffic) and one that was either just replaced or is being scaled down. The PRIMARY deployment is the one serving Jenkins; the other is the previous version until CodeDeploy terminates it. You don’t pick between them; CodeDeploy already moved the listener to the new set.
- **In CodeDeploy** (Application → Deployment group → Deployments): Each run of `scripts/dev/deploy-controller-blue-green.sh` creates one new **deployment ID** (e.g. `d-QCGA6A1EG`). Multiple IDs are deployment history. The latest **Succeeded** deployment is the one that performed the last traffic switch.

**How you use blue/green:** Run the deploy script when you want to release a new image; that creates a new deployment, starts new tasks on the inactive target group, and switches traffic when healthy. To undo a bad release, use [rollback](#rollback) in CodeDeploy (switch traffic back to the previous target group).

## Effect on EFS

The controller stores **Jenkins home** (`/var/jenkins_home`) on **EFS**. Both the “blue” and “green” controller task sets use the **same** EFS file system and access point (same task definition, same volume mount).

- **No extra configuration:** Blue/green does not change how EFS is used. New tasks (green) mount the same EFS as the old tasks (blue).
- **Same data across the switch:** When CodeDeploy switches traffic to the new set, the new controller sees the same jobs, config, and plugins because it’s the same EFS.
- **Single copy (no merge):** One EFS, one copy of the data. Blue and green both use the **same** files—there are no "two copies" to merge. "Resolving differences" is **avoiding concurrent-write conflicts**. To **eliminate overlap entirely** (only one controller using EFS at a time), use the [zero-overlap deploy](#zero-overlap-deployment-recommended-with-shared-efs) below; otherwise, during standard blue/green both task sets run briefly and you can reduce risk by avoiding heavy EFS writes during deploy or putting Jenkins in quiet mode.
- **Persistent agent:** The persistent agent also mounts this EFS. It talks to Jenkins via the ALB; the ALB sends to whichever controller target group is live. So blue/green does not affect the agent’s EFS mount or connectivity.

## First-time setup (no tasks until first deploy)

With CodeDeploy, the ECS service **does not start any tasks by itself**. Tasks are created only when you run a CodeDeploy deployment. After `terraform apply` creates the service, you must run an initial deployment to get the controller running:

```bash
./scripts/dev/build-and-push-controller.sh
./scripts/dev/deploy-controller-blue-green.sh
```

Until that deploy completes, the controller will show **0 running tasks**.

---

## Enabling blue/green

1. **New environment**: Set `controller_blue_green = true` in your `*.tfvars` (e.g. `dev.tfvars`). Default in the module is `false`.
2. **Existing environment**: Enabling blue/green **replaces the ECS service** (deployment controller type cannot be changed in-place). Run `terraform plan -var-file=dev.tfvars` first; you will see the service marked "forces replacement." After the old service is destroyed (or force-deleted), it may stay in **DRAINING** for several minutes. Use **`./scripts/dev/wait-and-apply-blue-green.sh`** to wait until draining finishes, then run `terraform apply` automatically. Alternatively, apply during a maintenance window and run `terraform apply` manually once the service is no longer draining.

## Deploying the controller

**Dev** has in-repo scripts below. For **nonprod** or **prod** with `controller_blue_green = true`, use the same flow: build and push with `./scripts/build-controller.sh <env>`, then trigger a CodeDeploy deployment using cluster, service, and deployment group from `terraform output` in that env (or add env-specific deploy scripts).

1. **Build and push** the controller image (same as before):
   ```bash
   ./scripts/dev/build-and-push-controller.sh
   ```

2. **Deploy with CodeDeploy** (blue/green) instead of “activate”:
   ```bash
   ./scripts/dev/deploy-controller-blue-green.sh
   ```
   This script fetches the current task definition, registers a new revision, and starts a CodeDeploy deployment. New tasks pull the image you pushed; once healthy, traffic is switched to the new target group.

Do **not** use `./scripts/dev/activate-controller.sh` when blue/green is enabled—that forces an ECS rolling deployment and does not use the second target group or traffic switching.

## Zero-overlap deployment (recommended with shared EFS)

To ensure **only one controller process uses EFS at a time** (no overlap), the blue/green script scales the service to 0 first, waits for all tasks to stop, then runs a CodeDeploy deployment to start the new version. Trade-off: **brief downtime** (typically a few minutes) while old tasks drain and new tasks start and pass health checks.

```bash
./scripts/dev/build-and-push-controller.sh
./scripts/dev/deploy-controller-blue-green.sh
```

Use this when you want to avoid any period where blue and green both have Jenkins running against the same EFS.

## Testing blue/green

To verify the switch works end-to-end:

1. **Optional: make a visible change** so you can tell new from old (e.g. add a line to the controller’s login page or set a build/env that shows in the UI). Or just use “deploy same image” to test the flow.

2. **Run a full deploy** (build → push → blue/green deploy):
   ```bash
   ./scripts/dev/build-and-push-controller.sh
   ./scripts/dev/deploy-controller-blue-green.sh
   ```
   The script waits for the CodeDeploy deployment to succeed (up to ~30 minutes).

3. **Watch in AWS (optional)**  
   - **ECS**: Cluster `jenkins-blue-green-dev-controller` → Service `jenkins` → Deployments. You’ll see a new deployment; when it completes, the “primary” task set is the one receiving traffic.  
   - **CodeDeploy**: Application `jenkins-blue-green-dev-controller` → Deployment group `jenkins-blue-green-dev-controller` → Deployments. Status should go to “Succeeded”; the listener will have been switched to the new target group.  
   - **EC2 → Target groups**: `jenkins-blue-green-dev-tg` (blue) and `jenkins-blue-green-dev-tg-green` (green). After a deploy, the listener points at whichever group has the new tasks; the other has 0 targets (old tasks terminated).

4. **Verify in the browser**  
   Open your Jenkins URL (e.g. the dev ALB). After the deploy completes, you should see the new version (or the same version if you didn’t change anything). No downtime: traffic flips when the new tasks pass health checks.

**Quick test without code changes:** run the two commands above with the current image. You’re testing that CodeDeploy brings up new tasks on the inactive group, switches the listener, and terminates the old tasks—Jenkins will look the same, but the deployment history in CodeDeploy/ECS will show the new run.

## Rolling deployment (controller_blue_green = false)

When blue/green is disabled, use the previous flow:

```bash
./scripts/dev/build-and-push-controller.sh
./scripts/dev/activate-controller.sh
```

## Persistent agent

The persistent agent does **not** use blue/green (no ALB). Deploy with:

```bash
./scripts/dev/build-and-push-agent.sh
./scripts/dev/activate-persistent-agent.sh
```

## Terraform resources (when controller_blue_green = true)

- **Second target group**: `aws_lb_target_group.nonprod_tg_green`
- **CodeDeploy application**: `aws_codedeploy_app.jenkins_controller`
- **CodeDeploy deployment group**: `aws_codedeploy_deployment_group.jenkins_controller` (links ECS service, blue/green TGs, ALB listener)
- **IAM role**: `aws_iam_role.codedeploy_ecs` (permissions to update listener and manage ECS task sets)

## Rollback

If the new version is unhealthy or misbehaves, use the CodeDeploy console or CLI to **stop the deployment** or **roll back** (switch traffic back to the previous target group). CodeDeploy keeps the previous task set until the deployment is finalized or rolled back.
