data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_region" "ireland" {
    provider = aws.ireland
}

locals {
  account_region  = data.aws_region.current.name
  account_id      = data.aws_caller_identity.current.account_id
  ireland_region  = data.aws_region.ireland.name

  privileged_mode = var.deploy_type == "ecr" || var.deploy_type == "ecs" || var.privileged_mode ? true : false
  artifact_attributes = (var.deploy_type == "lambda" ?
                          {
                            identifier_prefix = "function_zip"
                            object_name = "lambda.zip"
                          } :
                          {
                            identifier_prefix = "imagedefinitions_file"
                            object_name = "imagedefinitions.zip"
                          })
  codebuild_name = var.name
  codepipeline_name = var.name
}