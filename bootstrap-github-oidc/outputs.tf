output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_deploy.arn
  description = "Role ARN to use in GitHub Actions (configure-aws-credentials)"
}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}
