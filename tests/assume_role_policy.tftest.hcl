# Trust-policy guardrails: a role is only as safe as the policy that says who
# may assume it, so these runs pin down exactly which documents are rejected.
#
# `mock_provider` requires Terraform >= 1.7 (OpenTofu >= 1.7). That is a
# test-only requirement -- the module itself still supports >= 1.5, so
# versions.tf is deliberately not bumped for it.

mock_provider "aws" {}

variables {
  name = "example-role"
}

run "rejects_a_trust_policy_that_is_not_json" {
  command = plan

  variables {
    assume_role_policy = "not a policy"
  }

  expect_failures = [var.assume_role_policy]
}

run "rejects_wildcard_string_principal_without_condition" {
  command = plan

  variables {
    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = "*"
      }]
    })
  }

  expect_failures = [var.assume_role_policy]
}

run "rejects_wildcard_aws_principal_without_condition" {
  command = plan

  variables {
    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { AWS = "*" }
      }]
    })
  }

  expect_failures = [var.assume_role_policy]
}

run "rejects_wildcard_hidden_in_a_principal_list" {
  command = plan

  variables {
    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { AWS = ["arn:aws:iam::111122223333:root", "*"] }
      }]
    })
  }

  expect_failures = [var.assume_role_policy]
}

run "allows_wildcard_principal_that_is_narrowed_by_a_condition" {
  command = plan

  variables {
    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { AWS = "*" }
        Condition = { StringEquals = { "aws:PrincipalOrgID" = "o-exampleorgid" } }
      }]
    })
  }

  assert {
    condition     = aws_iam_role.this.name == "example-role"
    error_message = "A wildcard principal restricted by a Condition should be accepted."
  }
}

run "ignores_wildcard_principals_on_deny_statements" {
  command = plan

  variables {
    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect    = "Allow"
          Action    = "sts:AssumeRole"
          Principal = { Service = "ec2.amazonaws.com" }
        },
        {
          Effect    = "Deny"
          Action    = "sts:AssumeRole"
          Principal = "*"
          Condition = { BoolIfExists = { "aws:MultiFactorAuthPresent" = "false" } }
        },
      ]
    })
  }

  assert {
    condition     = aws_iam_role.this.name == "example-role"
    error_message = "A Deny statement with a wildcard principal is a restriction, not a grant, and should be accepted."
  }
}

run "rejects_oidc_principal_without_a_sub_condition" {
  command = plan

  variables {
    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect    = "Allow"
        Action    = "sts:AssumeRoleWithWebIdentity"
        Principal = { Federated = "arn:aws:iam::111122223333:oidc-provider/token.actions.githubusercontent.com" }
        Condition = { StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" } }
      }]
    })
  }

  expect_failures = [var.assume_role_policy]
}

run "rejects_oidc_principal_with_no_conditions_at_all" {
  command = plan

  variables {
    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect    = "Allow"
        Action    = "sts:AssumeRoleWithWebIdentity"
        Principal = { Federated = "arn:aws:iam::111122223333:oidc-provider/token.actions.githubusercontent.com" }
      }]
    })
  }

  expect_failures = [var.assume_role_policy]
}

run "allows_oidc_principal_pinned_to_a_sub_claim" {
  command = plan

  variables {
    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect    = "Allow"
        Action    = "sts:AssumeRoleWithWebIdentity"
        Principal = { Federated = "arn:aws:iam::111122223333:oidc-provider/token.actions.githubusercontent.com" }
        Condition = {
          StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
          StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:example-org/example-repo:*" }
        }
      }]
    })
  }

  assert {
    condition     = aws_iam_role.this.name == "example-role"
    error_message = "An OIDC trust policy that pins the :sub claim should be accepted."
  }
}

run "accepts_a_single_statement_object_rather_than_a_list" {
  command = plan

  variables {
    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    })
  }

  assert {
    condition     = aws_iam_role.this.name == "example-role"
    error_message = "A policy with a single Statement object should be accepted."
  }
}
