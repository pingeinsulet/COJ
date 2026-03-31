# Sane Promotion: Dev → Nonprod → Prod

This document describes the **promotion flow** for the Jenkins controller (and optional agent) across environments using a **Jenkins pipeline** with manual gates. The same code/ref is built and deployed in order: dev first, then nonprod after approval, then prod after approval.

## Overview

- **Promotion** = deploy the same branch/commit through the pipeline: build and deploy to **dev**, then (after gate) to **nonprod**, then (after gate) to **prod**.
- **Blue/green**: Dev uses CodeDeploy blue/green when `controller_blue_green = true`. Nonprod and prod use zero-overlap deploy (scale to 0, then new deployment); you can align them with CodeDeploy later if desired.
- **Gates**: Manual approval steps **"Promote to Nonprod?"** and **"Promote to Prod?"** so production is never updated without an explicit step.

## Jenkins Pipeline

Use the pipeline definition in this directory:

- **Path**: `blue-green/promotion/Jenkinsfile`
- **Job type**: Pipeline (from SCM or paste the Jenkinsfile).

### Parameters

| Parameter      | Description |
|----------------|-------------|
| `PROMOTE_TO`   | `dev` \| `nonprod` \| `prod` \| `all`. Deploy only up to this environment. `all` runs dev, then nonprod (after gate), then prod (after gate). |
| `GIT_REF`      | Branch or commit to build (e.g. `main`, `develop`, or a SHA). Default: `main`. |
| `DEPLOY_AGENT` | If true, also build and deploy the persistent agent in each environment. |

### Requirements

- **Agent**: Must have Docker, AWS CLI, Terraform, and (for controller build with Azure AD) `jq`. Use a label such as `jenkins-agent` (or adjust the `agent { label ... }` in the Jenkinsfile).
- **Workspace**: Checkout the repo so that the workspace is either:
  - The **repository root** that contains the `blue-green/` directory, or
  - The **blue-green** directory itself (e.g. if this repo is only the blue-green folder).
- **AWS**: Credentials must be configured for the account/region that hold dev, nonprod, and prod (or use role/credential binding per stage if you split accounts).

### Flow

1. **Checkout** the repo at `GIT_REF`.
2. **Dev**: Build controller (dev config), push to dev ECR, run dev blue/green deploy. Optionally build and activate the persistent agent in dev.
3. **Gate**: **"Promote to Nonprod?"** — manual approval.
4. **Nonprod**: Build controller (nonprod config), push to nonprod ECR, run nonprod deploy. Optionally build and activate the agent in nonprod.
5. **Gate**: **"Promote to Prod?"** — manual approval.
6. **Prod**: Build controller (prod config), push to prod ECR, run prod deploy. Optionally build and activate the agent in prod.

Each environment uses its own **Terraform-generated** `jenkins.yaml` (and ECR), so the image is built per environment from the same ref; promotion is "same code/version, promoted through envs" with manual gates.

## Terraform and GitHub

- **Terraform**: Infrastructure (ECS, ECR, ALB, CodeDeploy, etc.) is managed per environment under `environments/dev`, `environments/nonprod`, `environments/prod`. Apply Terraform **before** using the promotion pipeline so that ECR repos, ECS services, and (for dev) CodeDeploy resources exist. You can:
  - Run Terraform via **GitHub Actions** (e.g. `terraform.yml` workflow) per environment, or
  - Run Terraform from Jenkins in a **separate** job (e.g. "Terraform Plan/Apply dev → nonprod → prod") so promotion of **code** (this pipeline) and promotion of **infra** are explicit and auditable.
- **GitHub**: Use the same `GIT_REF` in the pipeline as the ref you want to promote (e.g. branch or tag). The pipeline does not need to be triggered by GitHub; you can run it manually or trigger it from a webhook when you want to promote.

## One-time setup in Jenkins

1. Create a **Pipeline** job.
2. Set **Pipeline** definition to "Pipeline script from SCM" and point to this repo, and set script path to **`blue-green/promotion/Jenkinsfile`** (or "Pipeline script" and reference that path).
3. Ensure the agent that runs the job has Docker, AWS CLI, Terraform, and `jq` and can authenticate to AWS.
4. Run with `PROMOTE_TO = all` (and optional `DEPLOY_AGENT`) to do a full promotion with gates.

## Rollback

- **Dev / Nonprod / Prod**: If the controller uses CodeDeploy (e.g. dev with `controller_blue_green = true`), use CodeDeploy rollback to switch traffic back. Otherwise, re-run the pipeline to a previous image or run the deploy scripts for that env with a previous task definition/image tag.
