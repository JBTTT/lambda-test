provider "aws" {
  region = "us-east-1"
}

module "lambda_sns" {
  source       = "../modules/lambda_sns"
  name_prefix  = "cet11-grp1-dev"
  alert_email  = "perseverancejb@hotmail.com"
}
