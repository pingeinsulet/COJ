# EFS file system for Jenkins home (jobs, workspaces, config, plugins).
#
# SAFETY: EFS must NEVER be deleted or overwritten. It holds persistent data.
# - prevent_destroy blocks Terraform from destroying this resource.
# - The destroy script (destroy-preserve-efs-ecr.sh) removes EFS from state before
#   destroy so Terraform never attempts deletion. Do not run raw "terraform destroy"
#   without using that script; if you do, prevent_destroy will error and block.
# - No script in this repo may call aws efs delete-file-system or wipe EFS contents.
resource "aws_efs_file_system" "nonprod_efs" {
  creation_token = "${var.prefix}-efs"
  encrypted      = true

  tags = {
    Name = "${var.prefix}-efs"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# EFS mount targets (required for EFS to be reachable). SAFETY: prevent_destroy — do not delete.
resource "aws_efs_mount_target" "nonprod_storage" {
  for_each        = { for subnet in var.private_subnets : subnet => true }
  file_system_id  = aws_efs_file_system.nonprod_efs.id
  subnet_id       = each.key
  security_groups = [aws_security_group.jenkins_nonprod_efs.id]

  lifecycle {
    prevent_destroy = true
  }
}

# EFS access point (path/perms for Jenkins). SAFETY: prevent_destroy — do not delete.
resource "aws_efs_access_point" "nonprod_efs_ap" {
  file_system_id = aws_efs_file_system.nonprod_efs.id

  # OS user and group applied to all file system requests made through this access point
  posix_user {
    uid = 0 # POSIX user ID
    gid = 0 # POSIX group ID
  }

  # The directory that this access point points to
  root_directory {
    path = "/var/jenkins_home"
    # POSIX user/group owner of this directory
    creation_info {
      owner_uid   = 1000 # Jenkins user
      owner_gid   = 1000 # Jenkins group
      permissions = "0755"
    }
  }

  tags = {
    Name = "${var.prefix}-efs-ap"
  }

  lifecycle {
    prevent_destroy = true
  }
}