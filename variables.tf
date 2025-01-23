variable "domain" {
  type        = string
  description = "Domain used for this deployment."
}

variable "certificate_domain"  {
  type        = string
  description = "Domain for the imported certificate. Used in conjunction with certificate_imported."
  default     = ""
}

variable "certificate_imported" {
  type        = bool
  description = "Look up an imported certificate instead of creating a managed one."
  default     = false
}

variable "custom_headers" {
  type        = map(string)
  description = "Custom headers to send to the origin."
  default     = {}
}

variable "environment" {
  type        = string
  description = "Environment for the deployment."
  default     = "dev"
}

variable "ip_set_rules" {
  type = map(object({
    name     = optional(string, "")
    action   = optional(string, "allow")
    priority = optional(number, null)
    arn      = string
  }))
  description = "Custom IP Set rules for the WAF."
  default     = {}
}

variable "log_bucket" {
  type        = string
  description = "S3 Bucket to send logs to."
}

variable "log_group" {
  type        = string
  description = "CloudWatch log group to send WAF logs to."
}

variable "origin_domain" {
  type        = string
  description = "Origin domain this deployment will point to. Defaults to origin.subdomain.domain."
  default     = ""
}

variable "passive" {
  type        = bool
  description = "Enable passive mode for the WAF, counting all requests rather than blocking."
  default     = false
}

variable "project" {
  type        = string
  description = "Project that these resources are supporting."
}

variable "rate_limit_rules" {
  type = map(object({
    name     = optional(string, "")
    action   = optional(string, "block")
    limit    = optional(number, 10)
    window   = optional(number, 60)
    priority = optional(number, null)
  }))
  description = "Rate limiting configuration for the WAF."
  default     = {}
}

variable "request_policy" {
  type        = string
  description = "Managed request policy to associate with the distribution."
  default     = "AllViewer"

  validation {
    condition = contains([
      "AllViewer",
      "AllViewerAndCloudFrontHeaders-2022-06",
      "AllViewerExceptHostHeader",
      "CORS-CustomOrigin",
      "CORS-S3Origin",
      "Elemental-MediaTailor-PersonalizedManifests",
      "UserAgentRefererHeaders"
    ], var.request_policy)
    error_message = "Invalid request policy. See https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html"
  }
}

variable "subdomain" {
  type        = string
  description = "Subdomain for the distribution. Defaults to the environment."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}

variable "upload_paths" {
  type = list(object({
    constraint = optional(string, "EXACTLY")
    path       = string
  }))
  description = "Paths to allow uploads to."
  default     = []
}

variable "webhooks" {
  type = map(object({
    paths = list(object({
      constraint = optional(string, "EXACTLY")
      path       = string
    }))
    criteria = optional(list(object({
      type       = string
      constraint = optional(string, "")
      name       = optional(string, "")
      field      = string
      value      = string
    })), [])
    action = optional(string, "allow")
  }))
  description = "Webhook paths to allow."
  default     = {}
}

variable "webhooks_priority" {
  type        = number
  description = "Priority for the webhooks rule group. By default, an attempt is made to place it before other rules that block traffic."
  default     = null
}
