resource "aws_iam_role" "this" {
  name                  = var.name
  description           = var.description
  path                  = var.path
  max_session_duration  = var.max_session_duration
  permissions_boundary  = var.permissions_boundary
  assume_role_policy    = var.assume_role_policy
  force_detach_policies = var.force_detach_policies

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "this" {
  for_each = var.inline_policies

  name   = each.key
  role   = aws_iam_role.this.name
  policy = each.value
}

# Customer-managed policies owned by this role. They are named after the role
# so that two roles using the same map key do not collide, since policy names
# are unique per account.
resource "aws_iam_policy" "this" {
  for_each = var.policy_documents

  name        = "${var.name}-${each.key}"
  path        = var.path
  description = "Managed by Terraform for role ${var.name}"
  policy      = each.value

  tags = var.tags

  lifecycle {
    precondition {
      condition     = length("${var.name}-${each.key}") <= 128
      error_message = "policy_documents key \"${each.key}\": the policy name \"${var.name}-${each.key}\" exceeds the 128-character IAM limit. Shorten the key or the role name."
    }
  }
}

resource "aws_iam_role_policy_attachment" "documents" {
  for_each = var.policy_documents

  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this[each.key].arn
}
