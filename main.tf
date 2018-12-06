####################################
# Data Sources
####################################
data "aws_region" "current" {}


#################################### 
# Provider
#################################### 
provider "aws" {
  region = "${var.Region}"
}


#################################### 
# Resources
#################################### 
# Config Service
module "config" {
  source  = "./modules/config-recorder"

  # Parameters
  S3Bucket = "${var.S3Bucket}"
  ConfigDeliverySnsTopicArn = "${var.ConfigDeliverySnsTopicArn}"
  DeliveryFrequency = "${var.DeliveryFrequency}"
  Region = "${data.aws_region.current.name}"
}

# S3 Bucket Encryption Enabled Rule
module "s3-bucket-encryption-config-rule" {
  source = "./modules/s3-bucket-encryption-config-rule"

  # Parameters
  S3BucketEncryptionEnabledConfigRuleName = "${var.S3BucketEncryptionEnabledConfigRuleName}"
  EncryptionType = "${var.EncryptionType}"
  KmsKey = "${var.KmsKey}"
  Region = "${data.aws_region.current.name}"
}

# # Enable S3 Bucket Encryption Lambda Function
module "enable-s3-bucket-encryption" {
  source = "./modules/enable-s3-bucket-encryption"

  # Parameters
  Region = "${data.aws_region.current.name}"
}