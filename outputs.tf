output "codebuild_project_id" {
  value = aws_codebuild_project.project.id
}

output "codebuild_project_arn" {
  value = aws_codebuild_project.project.arn
}

output "artifact_bucket_id" {
  value = aws_s3_bucket.artifact.id
}

output "artifact_bucket_arn" {
  value = aws_s3_bucket.artifact.arn
}

output "output_artifact_object_name" {
  value = (var.deploy_type == "lambda" ?
            "${var.function_name}/${local.artifact_attributes["object_name"]}" :
            var.deploy_type == "ecs" ? "${var.ecr_name}/${local.artifact_attributes["object_name"]}" : null)
}

output "codebuild_iam_role_name" {
  value = aws_iam_role.codebuild.id
}

output "codepipeline_id" {
  value = aws_codepipeline.pipeline.id
}

output "codepipeline_arn" {
  value = aws_codepipeline.pipeline.arn
}

output "ecr_repository_name" {
  value =  var.deploy_type == "ecr" || var.deploy_type == "ecs" ? aws_ecr_repository.repository[0].name : null
}

output "ecr_repository_url" {
  value = var.deploy_type == "ecr" || var.deploy_type == "ecs" ? aws_ecr_repository.repository[0].repository_url : null
}

output "ecr_repository_arn" {
  value = var.deploy_type == "ecr" || var.deploy_type == "ecs" ? aws_ecr_repository.repository[0].arn : null
}