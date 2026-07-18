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
