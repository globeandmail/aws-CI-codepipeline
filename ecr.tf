resource "aws_ecr_repository" "repository" {
  count = var.deploy_type == "ecr" || var.deploy_type == "ecs" ? 1 : 0
  name = var.ecr_name
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = var.tags
}

data "aws_iam_policy_document" "ecr_cross_account_get_access_policy" {
  count = var.deploy_type == "ecr" || var.deploy_type == "ecs" ? 1 : 0
  statement {
    sid = "Allow get access of the codebuild artifacts from deployment accounts"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:GetAuthorizationToken",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
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

resource "aws_ecr_repository_policy" "ecr_cross_account_get_access" {
  count = var.deploy_type == "ecr" || var.deploy_type == "ecs" ? 1 : 0
  repository = aws_ecr_repository.repository[0].name
  policy = data.aws_iam_policy_document.ecr_cross_account_get_access_policy[0].json
}