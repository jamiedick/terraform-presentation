#################################### 
# Parameter Values
#################################### 
# Congif Service Values
Region = "ap-south-1"
S3Bucket = "jamiedick-us-east-1"
ConfigDeliverySnsTopicArn = "arn:aws:sns:ap-south-1:610393807657:test-terraform"
DeliveryFrequency = "TwentyFour_Hours"

# S3 Bucket Encryption Config Rule Values
S3BucketEncryptionEnabledConfigRuleName = "s3-bucket-encryption-enabled-rule"
EncryptionType = "SSE-KMS"
KmsKey = "arn:aws:kms:ap-south-1:610393807657:key/b53427d4-aace-4701-a3ae-a90094d16369"
