output "sns_topic_arn" {
  value = aws_sns_topic.alert_topic.arn
}

output "lambda_name" {
  value = aws_lambda_function.iot_handler.function_name
}

output "event_rule_name" {
  value = aws_cloudwatch_event_rule.iot_rule.name
}
