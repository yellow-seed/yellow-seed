terraform {
  required_version = ">= 1.6.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  owner = var.github_owner
  token = var.github_token
}

resource "github_repository" "template" {
  name = var.repository_name

  description  = "Template for AI era Develop"
  homepage_url = ""
  visibility   = "public"
  is_template  = true
  archived     = false
  topics       = []

  has_issues      = true
  has_projects    = true
  has_wiki        = true
  has_downloads   = true
  has_discussions = false

  allow_forking          = true
  allow_merge_commit     = true
  allow_squash_merge     = true
  allow_rebase_merge     = true
  allow_auto_merge       = false
  delete_branch_on_merge = true
  allow_update_branch    = false

  squash_merge_commit_title   = "COMMIT_OR_PR_TITLE"
  squash_merge_commit_message = "COMMIT_MESSAGES"
  merge_commit_title          = "MERGE_MESSAGE"
  merge_commit_message        = "PR_TITLE"

  web_commit_signoff_required = false

  security_and_analysis {
    secret_scanning {
      status = "enabled"
    }
    secret_scanning_push_protection {
      status = "disabled"
    }
  }
}

resource "github_repository_vulnerability_alerts" "template" {
  repository = var.repository_name
  enabled    = true
}
