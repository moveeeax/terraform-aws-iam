# Role wiring and input validation. `mock_provider` requires Terraform >= 1.7
# (OpenTofu >= 1.7); that is a test-only requirement and versions.tf is
# deliberately left at >= 1.5.

mock_provider "aws" {}

variables {
  name = "example-role"

  assume_role_policy = <<-EOT
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": "sts:AssumeRole",
          "Principal": { "Service": "ec2.amazonaws.com" }
        }
      ]
    }
  EOT
}

run "defaults" {
  command = plan

  assert {
    condition     = aws_iam_role.this.max_session_duration == 3600
    error_message = "max_session_duration should default to one hour."
  }

  assert {
    condition     = aws_iam_role.this.path == "/"
    error_message = "path should default to /."
  }

  assert {
    condition     = aws_iam_role.this.permissions_boundary == null
    error_message = "No permissions boundary should be set unless one is requested."
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.this) == 0
    error_message = "No managed policies should be attached by default."
  }
}

run "attaches_every_managed_policy" {
  command = plan

  variables {
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
    ]
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.this) == 2
    error_message = "Every ARN in managed_policy_arns should get its own attachment."
  }
}

run "applies_a_permissions_boundary" {
  command = plan

  variables {
    permissions_boundary = "arn:aws:iam::111122223333:policy/example-boundary"
  }

  assert {
    condition     = aws_iam_role.this.permissions_boundary == "arn:aws:iam::111122223333:policy/example-boundary"
    error_message = "permissions_boundary should be passed through to the role."
  }
}

run "rejects_a_session_duration_below_the_aws_minimum" {
  command = plan

  variables {
    max_session_duration = 60
  }

  expect_failures = [var.max_session_duration]
}

run "rejects_a_session_duration_above_the_aws_maximum" {
  command = plan

  variables {
    max_session_duration = 86400
  }

  expect_failures = [var.max_session_duration]
}
