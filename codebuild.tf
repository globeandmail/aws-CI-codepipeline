resource "aws_cloudwatch_log_group" "group" {
  name              = "/aws/codebuild/${local.codebuild_name}"
  retention_in_days = var.logs_retention_in_days

  tags = var.tags
}

data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "codebuild-${local.codebuild_name}"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json

  tags = var.tags
}

data "aws_iam_policy_document" "codebuild_baseline" {
  statement {
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
    ]
    resources = [
      "arn:aws:logs:${local.account_region}:${local.account_id}:log-group:/aws/codebuild/${local.codebuild_name}",
      "arn:aws:logs:${local.account_region}:${local.account_id}:log-group:/aws/codebuild/${local.codebuild_name}:*"
    ]
  }

  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
    ]
    resources = [
      "${aws_s3_bucket.artifact.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "codebuild_baseline" {
  name   = "codebuild-baseline-${local.codebuild_name}"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild_baseline.json
}

data "aws_iam_policy_document" "codebuild_ecr" {
  count = var.deploy_type == "ecr" || var.deploy_type == "ecs" ? 1 : 0
  statement {

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage"
    ]

    resources = [
      aws_ecr_repository.repository[0].arn
    ]
  }

  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]

    resources = ["arn:aws:ecr:${local.account_region}:${local.account_id}:repository/*"]
  }

  statement {
    actions   = ["ssm:GetParameters"]
    resources = ["arn:aws:ssm:${local.account_region}:${local.account_id}:parameter/dockerhub/*"]
  }
}

resource "aws_iam_role_policy" "codebuild_ecr" {
  # Only create this if var.deploy_type is ecr or ecs
  count = var.deploy_type == "ecr" || var.deploy_type == "ecs" ? 1 : 0

  name   = "codebuild-ecr-${local.codebuild_name}"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild_ecr[count.index].json
}


data "aws_iam_policy_document" "codebuild_secrets_manager" {
  count = var.use_repo_access_github_token ? 1 : 0
  statement {
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      replace(var.central_account_github_token_aws_secret_arn, "/-.{6}$/", "-??????")
    ]
  }
}

resource "aws_iam_role_policy" "codebuild_secrets_manager" {
  count  = var.use_repo_access_github_token ? 1 : 0
  name   = "codebuild-secrets-manager-${local.codebuild_name}"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild_secrets_manager[0].json
}


data "aws_iam_policy_document" "codebuild_kms" {
  dynamic "statement" {
    for_each = var.use_repo_access_github_token && var.create_ireland_region_resources ? [1] : []
    content {
      actions = [
        "kms:Decrypt"
      ]

      resources = [
        var.central_account_github_token_aws_kms_cmk_arn,
        var.svcs_account_virginia_kms_cmk_arn_for_s3,
        var.svcs_account_ireland_kms_cmk_arn_for_s3
      ]
    }
  }

  dynamic "statement" {
    for_each = var.use_repo_access_github_token && !var.create_ireland_region_resources ? [1] : []
    content {
      actions = [
        "kms:Decrypt"
      ]

      resources = [
        var.central_account_github_token_aws_kms_cmk_arn,
        var.svcs_account_virginia_kms_cmk_arn_for_s3
      ]
    }
  }

  dynamic "statement" {
    for_each = !var.use_repo_access_github_token && var.create_ireland_region_resources ? [1] : []
    content {
      actions = [
        "kms:Decrypt"
      ]

      resources = [
        var.svcs_account_virginia_kms_cmk_arn_for_s3,
        var.svcs_account_ireland_kms_cmk_arn_for_s3
      ]
    }
  }

  dynamic "statement" {
    for_each = !var.use_repo_access_github_token && !var.create_ireland_region_resources ? [1] : []
    content {
      actions = [
        "kms:Decrypt"
      ]

      resources = [
        var.svcs_account_virginia_kms_cmk_arn_for_s3
      ]
    }
  }
}

resource "aws_iam_role_policy" "codebuild_kms" {
  name   = "codebuild-kms-${local.codebuild_name}"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild_kms.json
}

resource "aws_codebuild_project" "project" {
  name          = local.codebuild_name
  build_timeout = 60
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  dynamic "secondary_artifacts" {
    for_each = var.deploy_type == "lambda" || var.deploy_type == "ecs" ? [1]: []
    content {
      artifact_identifier = replace("${local.artifact_attributes["identifier_prefix"]}_${local.account_region}", "-", "_")
      location = aws_s3_bucket.artifact.id
      name = local.artifact_attributes["object_name"]
      namespace_type = "NONE"
      packaging = "ZIP"
      path = local.artifact_attributes["object_path"]
      type = "S3"
    }
  }

  environment {
    compute_type    = var.build_compute_type
    image           = var.codebuild_image
    type            = "LINUX_CONTAINER"
    privileged_mode = local.privileged_mode

    dynamic "environment_variable" {
      for_each = var.ecr_name == null ? [] : [1]
      content {
        name  = "IMAGE_REPO_NAME"
        value = var.ecr_name
      }
    }

    dynamic "environment_variable" {
      for_each = var.use_docker_credentials ? [1] : []
      content {
        name  = "DOCKERHUB_USER"
        value = "/dockerhub/user"
        type  = "PARAMETER_STORE"
      }
    }

    dynamic "environment_variable" {
      for_each = var.use_docker_credentials ? [1] : []
      content {
        name  = "DOCKERHUB_PASS"
        value = "/dockerhub/pass"
        type  = "PARAMETER_STORE"
      }
    }

    dynamic "environment_variable" {
      for_each = var.use_repo_access_github_token ? [1] : []
      content {
        name  = "REPO_ACCESS_GITHUB_TOKEN_SECRETS_ID"
        value = var.central_account_github_token_aws_secret_arn
        type = "SECRETS_MANAGER"
      }
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.buildspec
  }

  tags = var.tags
}