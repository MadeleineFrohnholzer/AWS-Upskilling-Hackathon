variable "region" {
  description = "AWS region for the state backend"
  type        = string
  default     = "eu-central-1"
}

variable "github_actions_policy_arn" {
  description = "ARN of the policy to attach to the GitHub Actions OIDC role (same as on GithubActionsHackathon)"
  type        = string
}
