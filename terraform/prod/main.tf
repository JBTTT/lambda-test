terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region      = us-east-1
}

module "lambda_sns_iot" {
  source      = "../modules/lambda_sns_iot"
  name_prefix = "cet11-grp1-prod"
  alert_email = "perseverancejb@hotmail.com"
}

module "iot_simulator_ec2" {
  source      = "../modules/iot_simulator_ec2"
  name_prefix = "cet11-grp1-prod"
  region      = us-east-1
}
