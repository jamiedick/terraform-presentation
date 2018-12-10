output "ConfigRuleLambdaArn" {
  value = "${module.s3-bucket-encryption-config-rule.LambdaArn}"
}

output "EnableEncryptionLambdaArn" {
  value = "${module.enable-s3-bucket-encryption.LambdaArn}"
}