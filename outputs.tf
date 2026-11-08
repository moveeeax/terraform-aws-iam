output "id" {
  description = "Name of the role."
  value       = aws_iam_role.this.id
}

output "arn" {
  description = "ARN of the role."
  value       = aws_iam_role.this.arn
}

output "name" {
  description = "Name of the role."
  value       = aws_iam_role.this.name
}

output "unique_id" {
  description = "Stable and unique string identifying the role."
  value       = aws_iam_role.this.unique_id
}

output "inline_policy_names" {
  description = "Names of the inline policies embedded in the role."
  value       = [for p in aws_iam_role_policy.this : p.name]
}

output "policy_arns" {
  description = "ARNs of the customer-managed policies created from policy_documents, keyed like the input map."
  value       = { for k, p in aws_iam_policy.this : k => p.arn }
}
