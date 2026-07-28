output "agent_id" {
  description = "Bedrock Agent ID — set as BEDROCK_AGENT_ID env var on the proxy container"
  value       = aws_bedrockagent_agent.main.id
}

output "agent_alias_id" {
  description = "Bedrock Agent Alias ID — set as BEDROCK_AGENT_ALIAS_ID env var on the proxy container"
  value       = aws_bedrockagent_agent_alias.live.agent_alias_id
}

output "agent_arn" {
  description = "Bedrock Agent ARN"
  value       = aws_bedrockagent_agent.main.agent_arn
}

output "agent_role_arn" {
  description = "IAM role ARN used by the Bedrock Agent"
  value       = aws_iam_role.agent.arn
}
