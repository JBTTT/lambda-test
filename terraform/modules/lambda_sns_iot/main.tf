data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda_src_iot"
  output_path = "${path.module}/lambda_iot.zip"
}

resource "aws_sns_topic" "alert_topic" {
  name = "${var.name_prefix}-iot-alert-topic"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.alert_topic.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.name_prefix}-iot-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_sns_policy" {
  name = "${var.name_prefix}-lambda-sns-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["sns:Publish"],
      Resource = [aws_sns_topic.alert_topic.arn]
    }]
  })
}

# ⭐ THIS IS THE LAMBDA RESOURCE NAME YOU MUST USE
resource "aws_lambda_function" "alert_lambda" {
  function_name = "${var.name_prefix}-iot-handler"
  filename      = data.archive_file.lambda_zip.output_path
  handler       = "index.handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_role.arn
  source_code_hash = filebase64sha256(data.archive_file.lambda_zip.output_path)

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alert_topic.arn
    }
  }
}

# ⭐ THIS IS THE EVENT RULE NAME YOU MUST USE
resource "aws_cloudwatch_event_rule" "event_rule" {
  name        = "${var.name_prefix}-iot-event"
  description = "Simulated IoT device events"

  event_pattern = jsonencode({
    "source": ["cet11.grp1.iot"],
    "detail-type": ["iot.telemetry"]
  })
}

resource "aws_cloudwatch_event_target" "event_target" {
  rule      = aws_cloudwatch_event_rule.event_rule.name
  target_id = "lambda-iot-target"
  arn       = aws_lambda_function.alert_lambda.arn
}

resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alert_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.event_rule.arn
}
