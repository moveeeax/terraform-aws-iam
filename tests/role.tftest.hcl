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

run "rejects_a_name_over_64_characters" {
  command = plan

  variables {
    name = join("", [for _ in range(65) : "a"])
  }

  expect_failures = [var.name]
}

run "rejects_a_name_with_disallowed_characters" {
  command = plan

  variables {
    name = "not a valid role name!"
  }

  expect_failures = [var.name]
}

run "rejects_a_path_without_leading_and_trailing_slashes" {
  command = plan

  variables {
    path = "team/backend"
  }

  expect_failures = [var.path]
}

run "accepts_a_well_formed_custom_path" {
  command = plan

  variables {
    path = "/team/backend/"
  }

  assert {
    condition     = aws_iam_role.this.path == "/team/backend/"
    error_message = "A well-formed custom path should be accepted and passed through."
  }
}

run "passes_through_force_detach_policies" {
  command = plan

  variables {
    force_detach_policies = true
  }

  assert {
    condition     = aws_iam_role.this.force_detach_policies == true
    error_message = "force_detach_policies should be passed through to the role so a role with unmanaged attachments can still be destroyed."
  }
}

# Update-in-place: for_each keyed by ARN means swapping one policy for
# another should add/remove only the changed attachment and must not force
# replacement of the role itself.
run "creates_with_two_managed_policies" {
  command = apply

  variables {
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
    ]
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.this) == 2
    error_message = "Both managed policies should be attached."
  }
}

run "swaps_one_managed_policy_without_replacing_the_role" {
  command = apply

  variables {
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess",
    ]
  }

  assert {
    condition     = aws_iam_role.this.name == "example-role"
    error_message = "Swapping a managed policy should update attachments in place, not replace the role."
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.this) == 2
    error_message = "Two attachments should remain after swapping one policy for another."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"].policy_arn == "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
    error_message = "The newly added policy should be attached."
  }

  assert {
    condition     = !contains(keys(aws_iam_role_policy_attachment.this), "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess")
    error_message = "The dropped policy should no longer be attached."
  }
}
