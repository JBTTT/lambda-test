terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

##############################
# SNS TOPIC & EMAIL SUBSCRIPTION
##############################

resource "aws_sns_topic" "alert_topic" {
  name = "cet11-grp1-event-alert-topic"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.alert_topic.arn
  protocol  = "email"
  endpoint  = "perseverancejb@hotmail.com"   # 🔔 CHANGE THIS
}

##############################
# IAM ROLE FOR LAMBDA
##############################

resource "aws_iam_role" "lambda_exec" {
  name = "cet11-grp1-lambda-alert-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
      Effect = "Allow"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-alert-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.alert_topic.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

##############################
# LAMBDA FUNCTION
##############################

resource "aws_lambda_function" "alert_lambda" {
  function_name = "event-alert-lambda"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "alert_handler.lambda_handler"
  runtime       = "python3.10"

  filename         = "lambda.zip"       # Zipped code
  source_code_hash = filebase64sha256("lambda.zip")

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alert_topic.arn
    }
  }
}

##############################
# EVENTBRIDGE RULE (TRIGGER)
##############################

# Sample rule: trigger when EC2 instance changes state
resource "aws_cloudwatch_event_rule" "ec2_state_change" {
  name        = "cet11-grp1-ec2-state-change-alert"
  description = "Triggers lambda when EC2 instance state changes"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"]
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.ec2_state_change.name
  target_id = "send-to-lambda"
  arn       = aws_lambda_function.alert_lambda.arn
}

# Allow EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alert_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ec2_state_change.arn
}
