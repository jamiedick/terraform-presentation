####################################
# Data Sources
####################################
data "archive_file" "source" {
  type        = "zip"
  source_dir  = "${path.module}/"
  output_path = "${path.module}/source.zip"
}

#################################### 
# Resources
#################################### 
# Lambda Function - enable s3 bucket encryption
resource "aws_lambda_function" "Function" {
  filename = "${path.module}/source.zip"
  function_name = "enable-s3-bucket-encryption"
  description = "Enables the encryption property on an s3 bucket"
  role = "${aws_iam_role.Role.arn}"
  handler = "enable-s3-bucket-encryption.lambda_handler"
  runtime = "python3.6"
  timeout = "30"
}

# CloudWatch Event to trigger Lambda Function
resource "aws_cloudwatch_event_rule" "CloudWatchEvent" {
  name        = "enable-s3-bucket-encryption"
  description = "Rule to run on compliance change of encryption on an s3 bucket as noted in AWS Config"

  event_pattern = <<PATTERN
{
  "source": ["aws.config"],
  "detail-type": ["Config Rules Compliance Change"],
  "detail": {"configRuleName":["s3-bucket-encryption-enabled-rule"]}
}
PATTERN
}

# CloudWatch Event Target
resource "aws_cloudwatch_event_target" "CloudWatchEventTarget" {
  rule      = "${aws_cloudwatch_event_rule.CloudWatchEvent.name}"
  target_id = "LambdaFunction"
  arn       = "${aws_lambda_function.Function.arn}"
}

# Invoke Permission
resource "aws_lambda_permission" "LambdaInvokePermission" {
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.Function.arn}"
  principal = "events.amazonaws.com"
  source_arn = "${aws_cloudwatch_event_rule.CloudWatchEvent.arn}"
}

# Role
resource "aws_iam_role" "Role" {
  name = "lambda-enable-s3-bucket-encryption-${var.Region}"
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
    actions = ["s3:PutEncryptionConfiguration", "config:DescribeConfigRules"]
    resources = ["*"]
  }
}

# Policy Document Attachment to Role
resource "aws_iam_role_policy" "PolicyAttachment" {
  name = "lambda-enable-s3-bucket-encryption-policy"
  role = "${aws_iam_role.Role.id}"
  policy = "${data.aws_iam_policy_document.Policy.json}"
}



