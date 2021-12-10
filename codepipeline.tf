data "aws_iam_policy_document" "codepipeline_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  name               = "codepipeline-ci-${local.codepipeline_name}"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume.json

  tags = var.tags
}

data "aws_iam_policy_document" "codepipeline_baseline" {
  statement {

    actions = [
      "s3:PutObject",
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.artifact.arn}/*"
    ]
  }

  statement {
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild"
    ]
    resources = [aws_codebuild_project.project.arn]
  }

}

resource "aws_iam_role_policy" "codepipeline_baseline" {
  name   = "codepipeline-ci-baseline-${local.codepipeline_name}"
  role   = aws_iam_role.codepipeline.id
  policy = data.aws_iam_policy_document.codepipeline_baseline.json
}

resource "aws_codepipeline" "pipeline" {
  name     = local.codepipeline_name
  role_arn = aws_iam_role.codepipeline.arn

  dynamic "artifact_store" {
    for_each = var.create_cross_region_resources ? [1] : []
    content {
      location = aws_s3_bucket.artifact.id
      type     = "S3"
      region   = local.account_region

      encryption_key {
          id   = var.svcs_account_virginia_kms_cmk_arn_for_s3
          type = "KMS"
      }
    }
  }

  dynamic "artifact_store" {
    for_each = !var.create_cross_region_resources ? [1] : []
    content {
      location = aws_s3_bucket.artifact.id
      type     = "S3"

      encryption_key {
          id   = var.svcs_account_virginia_kms_cmk_arn_for_s3
          type = "KMS"
      }
    }
  }

  dynamic "artifact_store" {
    for_each = var.create_ireland_region_resources ? [1] :[]
    content {
      location = aws_s3_bucket.artifact_ireland[0].id
      type     = "S3"
      region   = local.ireland_region

      encryption_key {
          id   = var.svcs_account_ireland_kms_cmk_arn_for_s3
          type = "KMS"
      }
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["code"]

      configuration = {
        Owner                = var.github_repo_owner
        Repo                 = var.github_repo_name
        Branch               = var.github_branch_name
        OAuthToken           = var.github_oauth_token
        PollForSourceChanges = "false"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["code"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.project.id
      }
    }
  }

  tags = var.tags
}

resource "aws_codepipeline_webhook" "github" {
  # Only create the webhook if create_github_webhook is set to true
  count           = var.create_github_webhook ? 1 : 0
  name            = local.codepipeline_name
  authentication  = "GITHUB_HMAC"
  target_action   = "Source"
  target_pipeline = aws_codepipeline.pipeline.name

  authentication_configuration {
    secret_token = var.github_oauth_token
  }

  filter {
    json_path    = "$.ref"
    match_equals = "refs/heads/{Branch}"
  }
}

resource "github_repository_webhook" "aws_codepipeline" {
  count      = var.create_github_webhook ? 1 : 0
  repository = var.github_repo_name

  configuration {
    url          = aws_codepipeline_webhook.github[0].url
    content_type = "json"
    secret       = var.github_oauth_token
  }

  events = ["push"]
}