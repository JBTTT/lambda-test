terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "region" {
  description = "AWS region for deployment"
  type        = string
}

provider "aws" {
  region = var.region
}

module "lambda_sns_iot" {
  source      = "../modules/lambda_sns_iot"
  name_prefix = "cet11-grp1-prod"
  alert_email = "perseverancejb@hotmail.com"
  region      = var.region
}

module "iot_simulator_ec2" {
  source      = "../modules/iot_simulator_ec2"
  name_prefix = "cet11-grp1-prod"
  region      = var.region
}
