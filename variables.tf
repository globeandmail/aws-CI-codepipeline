variable "name" { #reserved
  type        = string
  description = "(Required) The name associated with the pipeline and assoicated resources. i.e.: app-name."
}

variable "deploy_type" { #reserved
  type        = string
  description = "(Required) Must be one of the following ( ecr, ecs, lambda )."
}

variable "ecr_name" { #reserved
  type        = string
  description = "(Optional) The name of the ECR repo. Required if var.deploy_type is ecr or ecs."
  default     = null
}

variable "codebuild_image" { #reserved
  type        = string
  description = "(Optional) The codebuild image to use. Defaults to aws/codebuild/amazonlinux2-x86_64-standard:1.0."
  default     = "aws/codebuild/amazonlinux2-x86_64-standard:1.0"
}

variable "build_compute_type" { #reserved
  type        = string
  description = "(Optional) The codebuild environment compute type. Defaults to BUILD_GENERAL1_SMALL."
  default     = "BUILD_GENERAL1_SMALL"
}

variable "logs_retention_in_days" { #reserved
  type        = number
  description = "(Optional) Days to keep the cloudwatch logs for the codebuild project. Defaults to 14."
  default     = 14
}

variable "privileged_mode" { #reserved
  type        = bool
  description = "(Optional) Use privileged mode for docker containers. Defaults to false."
  default     = false
}

variable "tags" { #reserved
  type        = map
  description = "(Optional) A mapping of tags to assign to the resource"
  default     = {}
}

variable "github_repo_owner" { #reserved
  type        = string
  description = "(Required) The owner of the GitHub repo."
}

variable "github_repo_name" { #reserved
  type        = string
  description = "(Required) The name of the GitHub repository."
}

variable "github_branch_name" { #reserved
  type        = string
  description = "(Optional) The git branch name to use for the codebuild project. Defaults to master."
  default     = "master"
}

variable "github_oauth_token" { #reserved
  type        = string
  description = "(Required) The GitHub oauth token."
}

variable "lambda_function_name" { #reserved
  type        = string
  description = "(Optional) The name of the lambda function to update. Required if var.deploy_type is lambda."
  default     = null
}

variable "create_github_webhook" { #reserved
  type        = bool
  description = "(Optional) Create the github webhook that triggers codepipeline. Defaults to true."
  default     = true
}

variable "use_docker_credentials" { #reserved
  type        = bool
  description = "(Optional) Use dockerhub credentals stored in parameter store. Defaults to false."
  default     = false
}

variable "buildspec" { #reserved
  type        = string
  description = "(Optional) The name of the buildspec file to use with codebuild. Defaults to buildspec.yml."
  default     = "buildspec.yml"
}

variable "svcs_account_github_token_aws_secret_arn" { #reserved
  type        = string
  description = <<EOT
                (Optional) The AWS secret ARN for the repo access Github token.
                The secret is created in the shared service account.
                Required if var.use_repo_access_github_token is true.
                EOT
  default     = null
}

variable "svcs_account_github_token_aws_kms_cmk_arn" { #reserved
  type        = string
  description = <<EOT
                (Optional) The us-east-1 region AWS KMS customer managered key ARN for encrypting the repo access Github token AWS secret.
                The key is created in the shared service account.
                Required if var.use_repo_access_github_token is true.
                EOT
  default     = null
}

variable "non_default_aws_provider_configurations" {
  type = map(object({
    region_name = string,
    profile_name = string,
    allowed_account_ids = list(string)
  }))
  description = <<EOT
                (Required) A mapping of AWS provider configurations for cross-region resources creation.
                The configuration for Ireland region in the shared service account is required at the minimum.
                EOT
  default = {}
}

variable "use_repo_access_github_token" {
  type        = bool
  description = <<EOT
                (Optional) Allow the AWS codebuild IAM role read access to the REPO_ACCESS_GITHUB_TOKEN secrets manager secret in the shared service account.
                Defaults to false.
                EOT
  default     = false
}

variable "create_cross_region_resources" {
  type        = bool
  description = <<EOT
                (Required) Create the pipeline associated resources in all regions specified in var.non_default_aws_provider_configurations.
                Set to true if var.deploy_type is ecs or lambda.
                EOT
}

variable "create_ireland_region_resources" {
  type        = bool
  description = <<EOT
                (Required) Create the pipeline associated resources in the Ireland region.
                Set to true if var.deploy_type is ecs or lambda.
                EOT
}

variable "svcs_account_virginia_kms_cmk_arn_for_secrets_manager" {
  type        = string
  description = <<EOT
                (Optional) The us-east-1 region AWS KMS customer managed key ARN for encrypting secrets manager data.
                The key is created in the shared service account.
                Required if var.use_repo_access_github_token is true.
                EOT
  default     = null
}

variable "svcs_account_virginia_kms_cmk_arn_for_s3" {
  type        = string
  description = <<EOT
                (Optional) The us-east-1 region AWS KMS customer managed key ARN for encrypting s3 data.
                  The key is created in the shared service account.
                  Required if var.deploy_type is ecs or lambda.
                EOT
  default     = null
}

variable "svcs_account_ireland_kms_cmk_arn_for_s3" {
  type        = string
  description = <<EOT
                (Optional) The eu-west-1 region AWS KMS customer managed key ARN for encrypting s3 data.
                The key is created in the shared service account.
                Required if var.create_ireland_region_resources is true.
                EOT
  default     = null
}

variable "s3_bucket_force_destroy" {
  type        = bool
  description = <<EOT
                (Required) Delete all objects in S3 bucket upon bucket deletion. S3 objects are not recoverable.
                Set to true if var.deploy_type is ecs or lambda.
                EOT
}

variable "aws_organization_id" {
  type         = string
  description  = "(Required) The AWS organization ID."
}