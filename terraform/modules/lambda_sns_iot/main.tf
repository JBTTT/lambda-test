data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda_src_iot"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_sns_topic" "alert_topic" {
  name = "${var.name_prefix}-iot-topic"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.alert_topic.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "sns_policy" {
  name = "${var.name_prefix}-sns-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["sns:Publish"],
      Resource = aws_sns_topic.alert_topic.arn
    }]
  })
}

resource "aws_lambda_function" "alert_lambda" {
  function_name = "${var.name_prefix}-iot-handler"
  runtime       = "python3.11"
  handler       = "index.handler"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = filebase64sha256(data.archive_file.lambda_zip.output_path)

  role = aws_iam_role.lambda_role.arn

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alert_topic.arn
    }
  }
}

resource "aws_cloudwatch_event_rule" "event_rule" {
  name        = "${var.name_prefix}-iot-rule"
  description = "IoT Telemetry Rule"

  event_pattern = jsonencode({
    source      = ["cet11.grp1.iot"],
    detail-type = ["iot.telemetry"]
  })
}

resource "aws_cloudwatch_event_target" "event_target" {
  rule      = aws_cloudwatch_event_rule.event_rule.name
  target_id = "lambda"
  arn       = aws_lambda_function.alert_lambda.arn
}

resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowExecution"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alert_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.event_rule.arn
}
