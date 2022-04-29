# aws-ci-codepipeline
The AWS code pipeline for CI (i.e. build). It creates a codebuild project and S3 artifact bucket in a shared service account.
The output artifact can be used to trigger the code pipeline for CD (i.e. deployment) in other AWS account(s).
For multi-region build, modify the module to replicate the output artifact to an S3 bucket in the same region as the target deployment code pipeline.
The module currently supports multi-region build for lambda, ECS and ECR in the N.Virginia and Ireland regions.

## v1.0 Notes
1. The account that owns the github token must have admin access on the repo in order to generate a github webhook.
2. If `use_docker_credentials` is set to `true`, the environment variables `DOCKERHUB_USER` and `DOCKERHUB_PASS` are exposed via codebuild.

    You can add these 2 lines to the beginning of your `build` phase commands in `buildspec.yml` to login to Dockerhub.

    ```yml
    build:
        commands:
        - echo "Logging into Dockerhub..."
        - docker login -u ${DOCKERHUB_USER} -p ${DOCKERHUB_PASS}
        ...
        ...
    ```
3. If `use_repo_access_github_token` is set to `true`, the environment variable `REPO_ACCESS_GITHUB_TOKEN_SECRETS_ID` is exposed via codebuild.

    You can add this line to the beginning of your `build` phase commands in `buildspec.yml` to assign the environment variable to local variable `GITHUB_TOKEN`.

    ```yml
    build:
        commands:
        - export GITHUB_TOKEN=${REPO_ACCESS_GITHUB_TOKEN_SECRETS_ID}
        ...
        ...
        - docker build -t $REPOSITORY_URI:latest --build-arg GITHUB_TOKEN=${GITHUB_TOKEN} .
        ...
        ...
    ```
4. AWS CloudTrail data events need to be configured in the shared service account to log S3 object-level API operations in the codepipeline buckets. The logs will be forwarded to the logging bucket in the central logging account. For example of how to log all S3 bucket object events in CloudTrail, see terraform doc [here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudtrail).

## v1.1 Notes
If `s3_block_public_access` is set to `true`, the block public access setting for the artifact bucket is enabled.

## Usage
### Lambda
```hcl
module "lambda_ci_pipeline" {
  source = "github.com/globeandmail/aws-ci-codepipeline?ref=1.1"

  name                                     = "app-name"
  deploy_type                              = "lambda"
  aws_organization_id                      = "aws-organization-id"
  github_repo_owner                        = "github-account-name"
  github_repo_name                         = "github-repo-name"
  github_branch_name                       = "github-branch-name"
  github_oauth_token                       = data.aws_ssm_parameter.github_token.value
  non_default_aws_provider_configurations  = {
                                               ireland = {
                                                 region_name = "region-name",
                                                 profile_name = "profile-name",
                                                 allowed_account_ids = ["account-id"]
                                               }
                                             }
  lambda_function_name                     = "lambda-function-name"
  s3_bucket_force_destroy                  = true
  create_cross_region_resources            = true
  create_ireland_region_resources          = true
  svcs_account_ireland_kms_cmk_arn_for_s3  = "svcs-account-ireland-kms-cmk-arn-for-s3"
  svcs_account_virginia_kms_cmk_arn_for_s3 = "svcs-account-virginia-kms-cmk-arn-for-s3"
  s3_block_public_access                   = true
  tags                                     = {
                                               Environment = var.environment
                                             }
}
```

### ECS
```hcl
module "ecs_ci_pipeline" {
  source = "github.com/globeandmail/aws-ci-codepipeline?ref=1.1"

  name                                      = "app-name"
  deploy_type                               = "ecs"
  aws_organization_id                       = "aws-organization-id"
  github_repo_owner                         = "github-account-name"
  github_repo_name                          = "github-repo-name"
  github_branch_name                        = "github-branch-name"
  github_oauth_token                        = data.aws_ssm_parameter.github_token.value
  non_default_aws_provider_configurations   = {
                                                ireland = {
                                                  region_name = "region-name",
                                                  profile_name = "profile-name",
                                                  allowed_account_ids = ["account-id"]
                                                }
                                              }
  s3_bucket_force_destroy                   = true
  create_cross_region_resources             = true
  create_ireland_region_resources           = true
  svcs_account_ireland_kms_cmk_arn_for_s3   = "svcs-account-ireland-kms-cmk-arn-for-s3"
  svcs_account_virginia_kms_cmk_arn_for_s3  = "svcs-account-virginia-kms-cmk-arn-for-s3"
  ecr_name                                  = "ecr-repo-name"
  use_docker_credentials                    = true
  use_repo_access_github_token              = true
  svcs_account_github_token_aws_secret_arn  = "svcs-account-github-token-aws-secret-arn"
  svcs_account_github_token_aws_kms_cmk_arn = "svcs-account-github-token-aws-kms-cmk-arn"
  s3_block_public_access                   = true
  tags                                      = {
                                                Environment = var.environment
                                              }
}
```

### ECR
```hcl
module "ecr_ci_pipeline" {
  source = "github.com/globeandmail/aws-ci-codepipeline?ref=1.1"

  name                                      = "app-name"
  deploy_type                               = "ecr"
  aws_organization_id                       = "aws-organization-id"
  github_repo_owner                         = "github-account-name"
  github_repo_name                          = "github-repo-name"
  github_branch_name                        = "github-branch-name"
  github_oauth_token                        = data.aws_ssm_parameter.github_token.value
  non_default_aws_provider_configurations   = {
                                                ireland = {
                                                  region_name = "region-name",
                                                  profile_name = "profile-name",
                                                  allowed_account_ids = ["account-id"]
                                                }
                                              }
  create_cross_region_resources             = false
  create_ireland_region_resources           = false
  svcs_account_virginia_kms_cmk_arn_for_s3  = "svcs-account-virginia-kms-cmk-arn-for-s3"
  ecr_name                                  = "ecr-repo-name"
  use_docker_credentials                    = true
  use_repo_access_github_token              = true
  svcs_account_github_token_aws_secret_arn  = "svcs-account-github-token-aws-secret-arn"
  svcs_account_github_token_aws_kms_cmk_arn = "svcs-account-github-token-aws-kms-cmk-arn"
  s3_block_public_access                   = true
  tags                                      = {
                                                Environment = var.environment
                                              }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.12 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_aws.ireland"></a> [aws.ireland](#provider\_aws.ireland) | n/a |
| <a name="provider_github"></a> [github](#provider\_github) | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_organization_id"></a> [aws\_organization\_id](#input\_aws\_organization\_id) | (Required) The AWS organization ID. | `string` | n/a | yes |
| <a name="input_build_compute_type"></a> [build\_compute\_type](#input\_build\_compute\_type) | (Optional) The codebuild environment compute type. Defaults to BUILD\_GENERAL1\_SMALL. | `string` | `"BUILD_GENERAL1_SMALL"` | no |
| <a name="input_buildspec"></a> [buildspec](#input\_buildspec) | (Optional) The name of the buildspec file to use with codebuild. Defaults to buildspec.yml. | `string` | `"buildspec.yml"` | no |
| <a name="input_codebuild_image"></a> [codebuild\_image](#input\_codebuild\_image) | (Optional) The codebuild image to use. Defaults to aws/codebuild/amazonlinux2-x86\_64-standard:1.0. | `string` | `"aws/codebuild/amazonlinux2-x86_64-standard:1.0"` | no |
| <a name="input_create_cross_region_resources"></a> [create\_cross\_region\_resources](#input\_create\_cross\_region\_resources) | (Required) Create the pipeline associated resources in all regions specified in var.non\_default\_aws\_provider\_configurations.<br>                Set to true if var.deploy\_type is ecs or lambda. | `bool` | n/a | yes |
| <a name="input_create_github_webhook"></a> [create\_github\_webhook](#input\_create\_github\_webhook) | (Optional) Create the github webhook that triggers codepipeline. Defaults to true. | `bool` | `true` | no |
| <a name="input_create_ireland_region_resources"></a> [create\_ireland\_region\_resources](#input\_create\_ireland\_region\_resources) | (Required) Create the pipeline associated resources in the Ireland region.<br>                Set to true if var.deploy\_type is ecs or lambda. | `bool` | n/a | yes |
| <a name="input_deploy_type"></a> [deploy\_type](#input\_deploy\_type) | (Required) Must be one of the following ( ecr, ecs, lambda ). | `string` | n/a | yes |
| <a name="input_ecr_name"></a> [ecr\_name](#input\_ecr\_name) | (Optional) The name of the ECR repo. Required if var.deploy\_type is ecr or ecs. | `string` | `null` | no |
| <a name="input_github_branch_name"></a> [github\_branch\_name](#input\_github\_branch\_name) | (Optional) The git branch name to use for the codebuild project. Defaults to master. | `string` | `"master"` | no |
| <a name="input_github_oauth_token"></a> [github\_oauth\_token](#input\_github\_oauth\_token) | (Required) The GitHub oauth token. | `string` | n/a | yes |
| <a name="input_github_repo_name"></a> [github\_repo\_name](#input\_github\_repo\_name) | (Required) The name of the GitHub repository. | `string` | n/a | yes |
| <a name="input_github_repo_owner"></a> [github\_repo\_owner](#input\_github\_repo\_owner) | (Required) The owner of the GitHub repo. | `string` | n/a | yes |
| <a name="input_lambda_function_name"></a> [lambda\_function\_name](#input\_lambda\_function\_name) | (Optional) The name of the lambda function to update. Required if var.deploy\_type is lambda. | `string` | `null` | no |
| <a name="input_logs_retention_in_days"></a> [logs\_retention\_in\_days](#input\_logs\_retention\_in\_days) | (Optional) Days to keep the cloudwatch logs for the codebuild project. Defaults to 14. | `number` | `14` | no |
| <a name="input_name"></a> [name](#input\_name) | (Required) The name associated with the pipeline and assoicated resources. i.e.: app-name. | `string` | n/a | yes |
| <a name="input_non_default_aws_provider_configurations"></a> [non\_default\_aws\_provider\_configurations](#input\_non\_default\_aws\_provider\_configurations) | (Required) A mapping of AWS provider configurations for cross-region resources creation.<br>                The configuration for Ireland region in the shared service account is required at the minimum. | <pre>map(object({<br>    region_name = string,<br>    profile_name = string,<br>    allowed_account_ids = list(string)<br>  }))</pre> | `{}` | no |
| <a name="input_privileged_mode"></a> [privileged\_mode](#input\_privileged\_mode) | (Optional) Use privileged mode for docker containers. Defaults to false. | `bool` | `false` | no |
| <a name="input_s3_block_public_access"></a> [s3\_block\_public\_access](#input\_s3\_block\_public\_access) | (Optional) Enable the S3 block public access setting for the artifact bucket. | `bool` | `false` | no |
| <a name="input_s3_bucket_force_destroy"></a> [s3\_bucket\_force\_destroy](#input\_s3\_bucket\_force\_destroy) | (Optional) Delete all objects in S3 bucket upon bucket deletion. S3 objects are not recoverable.<br>                Set to true if var.deploy\_type is ecs or lambda. Defaults to false. | `bool` | `false` | no |
| <a name="input_svcs_account_github_token_aws_kms_cmk_arn"></a> [svcs\_account\_github\_token\_aws\_kms\_cmk\_arn](#input\_svcs\_account\_github\_token\_aws\_kms\_cmk\_arn) | (Optional) The us-east-1 region AWS KMS customer managed key ARN for encrypting the repo access Github token AWS secret.<br>                The key is created in the shared service account.<br>                Required if var.use\_repo\_access\_github\_token is true. | `string` | `null` | no |
| <a name="input_svcs_account_github_token_aws_secret_arn"></a> [svcs\_account\_github\_token\_aws\_secret\_arn](#input\_svcs\_account\_github\_token\_aws\_secret\_arn) | (Optional) The AWS secret ARN for the repo access Github token.<br>                The secret is created in the shared service account.<br>                Required if var.use\_repo\_access\_github\_token is true. | `string` | `null` | no |
| <a name="input_svcs_account_ireland_kms_cmk_arn_for_s3"></a> [svcs\_account\_ireland\_kms\_cmk\_arn\_for\_s3](#input\_svcs\_account\_ireland\_kms\_cmk\_arn\_for\_s3) | (Optional) The eu-west-1 region AWS KMS customer managed key ARN for encrypting s3 data.<br>                The key is created in the shared service account.<br>                Required if var.create\_ireland\_region\_resources is true. | `string` | `null` | no |
| <a name="input_svcs_account_virginia_kms_cmk_arn_for_s3"></a> [svcs\_account\_virginia\_kms\_cmk\_arn\_for\_s3](#input\_svcs\_account\_virginia\_kms\_cmk\_arn\_for\_s3) | (Required) The us-east-1 region AWS KMS customer managed key ARN for encrypting s3 data.<br>                  The key is created in the shared service account. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | (Optional) A mapping of tags to assign to the resource | `map` | `{}` | no |
| <a name="input_use_docker_credentials"></a> [use\_docker\_credentials](#input\_use\_docker\_credentials) | (Optional) Use dockerhub credentals stored in parameter store. Defaults to false. | `bool` | `false` | no |
| <a name="input_use_repo_access_github_token"></a> [use\_repo\_access\_github\_token](#input\_use\_repo\_access\_github\_token) | (Optional) Allow the AWS codebuild IAM role read access to the REPO\_ACCESS\_GITHUB\_TOKEN secrets manager secret in the shared service account.<br>                Defaults to false. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_artifact_bucket_arn"></a> [artifact\_bucket\_arn](#output\_artifact\_bucket\_arn) | n/a |
| <a name="output_artifact_bucket_id"></a> [artifact\_bucket\_id](#output\_artifact\_bucket\_id) | n/a |
| <a name="output_codebuild_iam_role_name"></a> [codebuild\_iam\_role\_name](#output\_codebuild\_iam\_role\_name) | n/a |
| <a name="output_codebuild_project_arn"></a> [codebuild\_project\_arn](#output\_codebuild\_project\_arn) | n/a |
| <a name="output_codebuild_project_id"></a> [codebuild\_project\_id](#output\_codebuild\_project\_id) | n/a |
| <a name="output_codepipeline_arn"></a> [codepipeline\_arn](#output\_codepipeline\_arn) | n/a |
| <a name="output_codepipeline_id"></a> [codepipeline\_id](#output\_codepipeline\_id) | n/a |
| <a name="output_ecr_repository_arn"></a> [ecr\_repository\_arn](#output\_ecr\_repository\_arn) | n/a |
| <a name="output_ecr_repository_name"></a> [ecr\_repository\_name](#output\_ecr\_repository\_name) | n/a |
| <a name="output_ecr_repository_url"></a> [ecr\_repository\_url](#output\_ecr\_repository\_url) | n/a |
| <a name="output_output_artifact_object_name"></a> [output\_artifact\_object\_name](#output\_output\_artifact\_object\_name) | n/a |
<!-- END_TF_DOCS -->

## Builspec examples
### Lambda
```yml
version: 0.2

phases:
  install:
    runtime-versions:
      python: 3.7
  build:
    commands:
      - pip install --upgrade pip
      - pip install -r requirements.txt -t .
artifacts:
  files:
    - '**/*'
  secondary-artifacts:
    function_zip_us_east_1:
      files:
        - '**/*'
      name: lambda.zip
```

### ECS
```yml
version: 0.2

env:
  variables:
    IMAGE_REPO_NAME: "ecr-repo-name"

phases:
  install:
    runtime-versions:
      docker: 18
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - $(aws ecr get-login --region $AWS_DEFAULT_REGION --no-include-email)
      - AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
      - REPOSITORY_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${IMAGE_REPO_NAME}
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=${COMMIT_HASH:=latest}
  build:
    commands:
      - echo Build started on `date`
      - echo Building the Docker image...
      - docker build -t $REPOSITORY_URI:latest .
      - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker images...
      - docker push $REPOSITORY_URI:latest
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - echo Generating imagedefinitions.json
      - printf '[{"name":"%s","imageUri":"%s"}]' $IMAGE_REPO_NAME $REPOSITORY_URI:$IMAGE_TAG > $CODEBUILD_SRC_DIR/imagedefinitions.json

artifacts:
  files: imagedefinitions.json
  secondary-artifacts:
    imagedefinitions_file_us_east_1:
      files:
        - imagedefinitions.json
      name: imagedefinitions.zip
```

### ECR
```yml
version: 0.2

env:
  variables:
    IMAGE_REPO_NAME: "ecr-repo-name"

phases:
  install:
    runtime-versions:
      docker: 18
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - $(aws ecr get-login --region $AWS_DEFAULT_REGION --no-include-email)
      - AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
      - REPOSITORY_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${IMAGE_REPO_NAME}
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=${COMMIT_HASH:=latest}
  build:
    commands:
      - echo Build started on `date`
      - echo Building the Docker image...
      - docker build -t $REPOSITORY_URI:latest .
      - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker images...
      - docker push $REPOSITORY_URI:latest
      - docker push $REPOSITORY_URI:$IMAGE_TAG
```