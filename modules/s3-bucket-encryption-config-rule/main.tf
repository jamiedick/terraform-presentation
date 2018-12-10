####################################
# Data Sources
####################################
data "archive_file" "source" {
  type        = "zip"
  source_dir  = "${path.module}/"
  output_path = "source.zip"
}


#################################### 
# Resources
#################################### 
# Config Rule
resource "aws_config_config_rule" "ConfigRule" {
  name = "${var.S3BucketEncryptionEnabledConfigRuleName}"
  description = "Checks whether S3 Buckets have encryption enabled."
  
  input_parameters = <<EOF
{
  "EncryptionType" : "${var.EncryptionType}",
  "KmsKey" : "${var.KmsKey}"
}
EOF

  scope = {
    compliance_resource_types = ["AWS::S3::Bucket"]
  }

  source {
    owner = "CUSTOM_LAMBDA"
    source_detail = {
      event_source = "aws.config",
      message_type = "ConfigurationItemChangeNotification"
    }
    source_identifier = "${aws_lambda_function.Function.arn}"
  }
  
  depends_on = ["aws_lambda_function.Function"]

}

# Lambda Function - backend support of config rule
resource "aws_lambda_function" "Function" {
  filename = "source.zip"
  function_name = "s3-bucket-encryption-enabled-rule"
  description = "Evaluates S3 Buckets for encryption configuration, puts compliance results into AWS Config"
  role = "${aws_iam_role.Role.arn}"
  handler = "s3-bucket-encryption-config-rule.lambda_handler"
  runtime = "python3.6"
  timeout = "30"
}

# Invoke Permission
resource "aws_lambda_permission" "LambdaInvokePermission" {
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.Function.arn}"
  principal = "config.amazonaws.com"
}

# Role
resource "aws_iam_role" "Role" {
  name = "lambda-s3-bucket-encryption-enabled-rule-${var.Region}"
  assume_role_policy = "${data.aws_iam_policy_document.AssumeRolePolicy.json}"
}

# Assume Role Policy Document
data "aws_iam_policy_document" "AssumeRolePolicy" {
  statement {
    sid = "AllowLambdaToAssumeRole"
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Policy Document
data "aws_iam_policy_document" "Policy" {
  statement {
    sid = "AllowLambdaToWriteLogs"
    effect = "Allow"
    actions = ["logs:*"]
    resources = ["arn:aws:logs:*:*:*"]
  }
  statement {
    sid = "AllowLambda"
    effect = "Allow"
    actions = ["config:PutEvaluations", "s3:GetEncryptionConfiguration"]
    resources = ["*"]
  }
}

# Policy Document Attachment to Role
resource "aws_iam_role_policy" "PolicyAttachment" {
  name = "lambda-s3-bucket-encryption-enabled-rule-policy"
  role = "${aws_iam_role.Role.id}"
  policy = "${data.aws_iam_policy_document.Policy.json}"
}