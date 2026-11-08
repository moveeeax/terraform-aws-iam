# Inline and customer-managed policies created alongside the role. Plan-only,
# against a mocked provider; `mock_provider` requires Terraform >= 1.7
# (OpenTofu >= 1.7).

# The attachment validates policy_arn at plan time, so the mocked policy needs
# a well-formed ARN rather than the random string mocks generate by default.
mock_provider "aws" {
  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::111122223333:policy/mocked"
    }
  }
}

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

run "defaults_create_no_policies" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy.this) == 0 && length(aws_iam_policy.this) == 0 && length(aws_iam_role_policy_attachment.documents) == 0
    error_message = "No inline or customer-managed policy may be created unless one is requested."
  }

  assert {
    condition     = length(output.inline_policy_names) == 0 && length(output.policy_arns) == 0
    error_message = "The policy outputs must be empty by default."
  }
}

run "embeds_every_inline_policy" {
  command = plan

  variables {
    inline_policies = {
      read-bucket = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["s3:GetObject"], Resource = "arn:aws:s3:::example-bucket/*" }] })
      write-logs = jsonencode({
        Version   = "2012-10-17"
        Statement = [{ Effect = "Allow", Action = ["logs:PutLogEvents"], Resource = "*" }]
      })
    }
  }

  assert {
    condition     = length(aws_iam_role_policy.this) == 2
    error_message = "Every entry in inline_policies must become an aws_iam_role_policy."
  }

  assert {
    condition     = aws_iam_role_policy.this["read-bucket"].name == "read-bucket"
    error_message = "The inline policy name must be the map key."
  }

  assert {
    condition     = aws_iam_role_policy.this["read-bucket"].role == "example-role"
    error_message = "Inline policies must be embedded in this module's role."
  }

  assert {
    condition     = toset(output.inline_policy_names) == toset(["read-bucket", "write-logs"])
    error_message = "inline_policy_names must list every inline policy."
  }
}

run "creates_and_attaches_customer_managed_policies" {
  command = plan

  variables {
    path             = "/team/backend/"
    policy_documents = { read-bucket = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["s3:GetObject"], Resource = "arn:aws:s3:::example-bucket/*" }] }) }
  }

  assert {
    condition     = aws_iam_policy.this["read-bucket"].name == "example-role-read-bucket"
    error_message = "Customer-managed policies must be named <role name>-<key>."
  }

  assert {
    condition     = aws_iam_policy.this["read-bucket"].path == "/team/backend/"
    error_message = "Customer-managed policies must be created under the role's path."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.documents["read-bucket"].role == "example-role"
    error_message = "Each customer-managed policy must be attached to this module's role."
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.this) == 0
    error_message = "policy_documents must not add entries to the managed_policy_arns attachments."
  }
}

run "rejects_an_inline_policy_that_is_not_json" {
  command = plan

  variables {
    inline_policies = { broken = "not a policy" }
  }

  expect_failures = [var.inline_policies]
}

run "rejects_an_inline_policy_name_with_disallowed_characters" {
  command = plan

  variables {
    inline_policies = { "read bucket!" = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["s3:GetObject"], Resource = "arn:aws:s3:::example-bucket/*" }] }) }
  }

  expect_failures = [var.inline_policies]
}

run "rejects_an_inline_policy_name_over_128_characters" {
  command = plan

  variables {
    inline_policies = { (join("", [for _ in range(129) : "a"])) = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["s3:GetObject"], Resource = "arn:aws:s3:::example-bucket/*" }] }) }
  }

  expect_failures = [var.inline_policies]
}

run "rejects_a_policy_document_that_is_not_json" {
  command = plan

  variables {
    policy_documents = { broken = "{" }
  }

  expect_failures = [var.policy_documents]
}

run "rejects_a_policy_document_key_with_disallowed_characters" {
  command = plan

  variables {
    policy_documents = { "read/bucket" = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["s3:GetObject"], Resource = "arn:aws:s3:::example-bucket/*" }] }) }
  }

  expect_failures = [var.policy_documents]
}

run "rejects_a_customer_managed_policy_name_over_128_characters" {
  command = plan

  variables {
    policy_documents = { (join("", [for _ in range(120) : "a"])) = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["s3:GetObject"], Resource = "arn:aws:s3:::example-bucket/*" }] }) }
  }

  expect_failures = [aws_iam_policy.this]
}
