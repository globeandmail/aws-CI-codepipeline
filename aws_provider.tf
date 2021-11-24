provider "aws" {
  alias = "ireland"
  profile = lookup(var.non_default_aws_provider_configurations["ireland"], "profile_name")
  region = lookup(var.non_default_aws_provider_configurations["ireland"], "region_name")
  allowed_account_ids = lookup(var.non_default_aws_provider_configurations["ireland"], "allowed_account_ids")
}

provider "github" {
  token = var.github_oauth_token
  owner = var.github_repo_owner
}