# Config Recorder Parameters
variable "S3Bucket" {
  description = "The name of the S3 bucket used to store the configuration history."
}
variable "ConfigDeliverySnsTopicArn" {
  description = "The ARN of the SNS topic that AWS Config delivers notifications to."
}
variable "DeliveryFrequency" {
  description = "The frequency with which AWS Config recurringly delivers configuration snapshots"
}

# S3 Bucket Encryption Enabled Rule
variable "S3BucketEncryptionEnabledConfigRuleName" {
  description = "The name that you assign to the AWS Config rule."
}
variable "EncryptionType" {
  description = "Type of encryption to be used on S3 buckets."
}
variable "KmsKey" {
  description = "KMS Key to use to encrypt S3 buckets, if applicable."
}
