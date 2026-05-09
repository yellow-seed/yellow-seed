variable "github_owner" {
  description = "GitHub owner or organization name"
  type        = string
}

variable "github_token" {
  description = "GitHub token with repository admin permission"
  type        = string
  sensitive   = true
}

variable "repository_name" {
  description = "Target repository name"
  type        = string
}
