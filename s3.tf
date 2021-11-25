resource "aws_s3_bucket" "artifact" {
  # S3 bucket cannot be longer than 63 characters
  bucket = lower(substr("codepipeline-ci-${local.account_region}-${local.account_id}-${var.name}", 0, 63))
  acl    = "private"
  force_destroy = var.s3_bucket_force_destroy

  dynamic "versioning" {
    for_each = var.deploy_type == "lambda" || var.deploy_type == "ecs" ? [1] : []
    content {
      enabled = true
    }
  }

  dynamic "replication_configuration" {
    for_each = var.create_cross_region_resources ? [1] : []
    content {
      role = aws_iam_role.artifact_replication[0].arn

      dynamic "rules" {
        for_each = var.create_ireland_region_resources ? [1] : []
        content {
          id     = "ireland_region_bucket_replication"
          status = "Enabled"

          prefix = local.artifact_attributes["object_path"]
          source_selection_criteria {
            sse_kms_encrypted_objects  {
              enabled = true
            }
          }

          destination {
            bucket        = aws_s3_bucket.artifact_ireland[0].arn
            storage_class = "STANDARD"
            replica_kms_key_id  = var.svcs_account_ireland_kms_cmk_arn_for_s3
          }
        }
      }
    }
  }

  lifecycle_rule {
    enabled = true

    abort_incomplete_multipart_upload_days = 30

    expiration {
      days = 90
    }

    dynamic "noncurrent_version_expiration" {
      for_each = var.deploy_type == "lambda" || var.deploy_type == "ecs" ? [1] : []
      content {
        days = 30
      }
    }
  }

  tags = var.tags
}

data "aws_iam_policy_document" "artifact_bucket_policy" {
  count = var.deploy_type == "lambda" || var.deploy_type == "ecs" ? 1 : 0
  statement {
    sid = "Allow get object access of the codebuild artifacts from deployment accounts"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetObjectAcl"
    ]

    resources = [
      "${aws_s3_bucket.artifact.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"

      values = [
          var.aws_organization_id
      ]
    }
  }

  statement {
    sid = "Allow list object access of the codebuild artifacts from deployment accounts"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = [
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:ListBucketMultipartUploads",
      "s3:GetBucket*"
    ]

    resources = [
      aws_s3_bucket.artifact.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"

      values = [
          var.aws_organization_id
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "artifact_bucket" {
  count = var.deploy_type == "lambda" || var.deploy_type == "ecs" ? 1 : 0
  bucket = aws_s3_bucket.artifact.id
  policy = data.aws_iam_policy_document.artifact_bucket_policy[0].json
}

# S3 cross-region replication
data "aws_iam_policy_document" "s3_assume" {
  count = var.create_cross_region_resources ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "artifact_replication" {
  count = var.create_cross_region_resources ? 1 : 0
  name               = "artifact-replication-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.s3_assume[0].json

  tags = var.tags
}

data "aws_iam_policy_document" "s3_replicate_access" {
  count = var.create_cross_region_resources ? 1 : 0
  statement {
    effect = "Allow"

    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.artifact.arn
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging"
    ]

    resources = [
      "${aws_s3_bucket.artifact.arn}/*"
    ]
  }

  dynamic "statement" {
    for_each = var.create_ireland_region_resources ? [1] : []
    content {
      effect = "Allow"

      actions = [
        "s3:ReplicateObject",
        "s3:ReplicateDelete",
        "s3:ReplicateTags"
      ]

      resources = [
        "${aws_s3_bucket.artifact_ireland[0].arn}/*"
      ]
    }
  }
}

resource "aws_iam_role_policy" "s3_replicate_access_policy" {
  count  = var.create_cross_region_resources ? 1 : 0
  name   = "s3-replicate-access"
  role   = aws_iam_role.artifact_replication[0].name
  policy = data.aws_iam_policy_document.s3_replicate_access[0].json
}

data "aws_iam_policy_document" "kms_full_access" {
  count = var.create_cross_region_resources ? 1 : 0
  statement {
    actions = [
      "kms:Decrypt"
    ]
    resources = [
      var.svcs_account_virginia_kms_cmk_arn_for_s3
    ]
  }

  dynamic "statement" {
    for_each = var.create_ireland_region_resources ? [1] :[]
    content {
      actions = [
        "kms:Encrypt"
      ]

      resources = [
        var.svcs_account_ireland_kms_cmk_arn_for_s3
      ]
    }
  }
}

resource "aws_iam_role_policy" "kms_full_access_policy" {
  count = var.create_cross_region_resources ? 1 : 0
  name = "kms-full-access"
  role   = aws_iam_role.artifact_replication[0].name
  policy = data.aws_iam_policy_document.kms_full_access[0].json
}

# Cross-Region Resources
resource "aws_s3_bucket" "artifact_ireland" {
  count  = var.create_ireland_region_resources ? 1 : 0
  # S3 bucket cannot be longer than 63 characters
  bucket = lower(substr("codepipeline-ci-${local.ireland_region}-${local.account_id}-${var.name}", 0, 63))
  acl    = "private"
  force_destroy = var.s3_bucket_force_destroy
  provider = aws.ireland

  versioning {
    enabled = true
  }

  lifecycle_rule {
    enabled = true

    abort_incomplete_multipart_upload_days = 30

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
        days = 30
    }
  }

  tags = var.tags
}

data "aws_iam_policy_document" "artifact_bucket_ireland_policy" {
  count = var.create_ireland_region_resources ? 1 : 0
  statement {
    sid = "Allow get object access of the codebuild artifacts from deployment accounts"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetObjectAcl"
    ]

    resources = [
      "${aws_s3_bucket.artifact_ireland[0].arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"

      values = [
          var.aws_organization_id
      ]
    }
  }

  statement {
    sid = "Allow list object access of the codebuild artifacts from deployment accounts"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = [
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:ListBucketMultipartUploads",
      "s3:GetBucket*"
    ]

    resources = [
      aws_s3_bucket.artifact_ireland[0].arn
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"

      values = [
          var.aws_organization_id
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "artifact_bucket_ireland" {
  count = var.create_ireland_region_resources ? 1 : 0
  provider = aws.ireland
  bucket = aws_s3_bucket.artifact_ireland[0].id
  policy = data.aws_iam_policy_document.artifact_bucket_ireland_policy[0].json
}