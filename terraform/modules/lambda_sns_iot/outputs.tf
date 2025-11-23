output "lambda_name" {
  value = aws_lambda_function.alert_lambda.function_name
}

output "sns_topic_arn" {
  value = aws_sns_topic.alert_topic.arn
}
