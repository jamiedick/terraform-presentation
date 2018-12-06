####################################
# Data Sources
####################################
data "aws_caller_identity" "current" {}


####################################
# Local Variables
####################################
locals {
  account_id = "${data.aws_caller_identity.current.account_id}"
}


#################################### 
# Resources
#################################### 
# Config Recorder
resource "aws_config_configuration_recorder" "ConfigRecorder" {
  role_arn = "${aws_iam_role.ConfigRole.arn}"
  recording_group {
    all_supported = true
    include_global_resource_types = true
  }
  depends_on = ["aws_iam_role.ConfigRole"]
}

# Config Recorder Status
resource "aws_config_configuration_recorder_status" "ConfigRecorderStatus" {
  name = "${aws_config_configuration_recorder.ConfigRecorder.name}"
  is_enabled = true
  depends_on = ["aws_config_delivery_channel.DeliveryChannel"]
}

# Delivery Channel
resource "aws_config_delivery_channel" "DeliveryChannel" {
  s3_bucket_name = "${var.S3Bucket}"
  sns_topic_arn = "${var.ConfigDeliverySnsTopicArn}"
  snapshot_delivery_properties {
    delivery_frequency = "${var.DeliveryFrequency}"
  }
  depends_on = ["aws_config_configuration_recorder.ConfigRecorder"]
}

# Config Role - Assume Role Policy Document
data "aws_iam_policy_document" "ConfigAssumeRolePolicy" {
  statement {
    sid = "AllowConfigToAssumeRole"
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

# Config Role
resource "aws_iam_role" "ConfigRole" {
  name = "config-${var.Region}"
  assume_role_policy = "${data.aws_iam_policy_document.ConfigAssumeRolePolicy.json}"
}

# Config Role - Policy Document
data "aws_iam_policy_document" "ConfigPolicy" {
  statement {
    sid = "AllowConfigToPutObjects"
    effect = "Allow"
    actions = ["s3:PutObject*"]
    resources = ["arn:aws:s3:::${var.S3Bucket}/AWSLogs/${local.account_id}/*"]
    condition {
      test     = "StringLike"
      variable = "s3:x-amz-acl"
      values = ["bucket-owner-full-control"]
    }
  }
  statement {
    sid = "AllowConfigToReadBucketAcl"
    effect = "Allow"
    actions = ["s3:GetBucketAcl"]
    resources = ["arn:aws:s3:::${var.S3Bucket}"]

  }
}

# Config Role Policy
resource "aws_iam_role_policy" "ConfigRolePolicy" {
  name = "config-role-policy"
  role = "${aws_iam_role.ConfigRole.id}"
  policy = "${data.aws_iam_policy_document.ConfigPolicy.json}"

}

# Managed Config Policy Attachment to Config Role
resource "aws_iam_role_policy_attachment" "AttachManagedPolicyToRole" {
    role = "${aws_iam_role.ConfigRole.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}