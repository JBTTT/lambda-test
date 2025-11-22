output "lambda_name" {
  value = aws_lambda_function.alert_lambda.function_name
}

output "event_rule_name" {
  value = aws_cloudwatch_event_rule.event_rule.name
}

output "sns_topic_arn" {
  value = aws_sns_topic.alert_topic.arn
}
