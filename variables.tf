variable "domain" {
  type        = string
  description = "Domain used for this deployment."
}

variable "certificate_domain" {
  type        = string
  description = <<-EOT
    Domain for the imported certificate, if different from the endpoint. Used in
    conjunction with `certificate_imported`.
    EOT
  default     = null
}

variable "certificate_imported" {
  type        = bool
  description = <<-EOT
    Look up an imported certificate instead of creating a managed one.
    EOT
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
  default     = "development"
}

variable "ip_set_rules" {
  type = map(object({
    name     = optional(string, null)
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

variable "origin_alb_arn" {
  type        = string
  description = <<-EOT
    ARN of the Application Load Balancer this deployment will point to. Required
    unless `use_custom_origin` is set to `true`.
    EOT
  default     = null

  validation {
    condition     = var.use_custom_origin || (var.origin_alb_arn != null && var.origin_alb_arn != "")
    error_message = <<-EOT
      origin_alb_arn must be set to a non-empty value unless use_custom_origin
      is true.
      EOT
  }
}

variable "origin_domain" {
  type        = string
  description = <<-EOT
    Optional custom origin domain to point to. Defaults to
    `origin.subdomain.domain`. Only used if `use_custom_origin` is set to
    `true`.
    EOT
  default     = null
}

variable "passive" {
  type        = bool
  description = <<-EOT
    Enable passive mode for the WAF, counting all requests rather than blocking.
    EOT
  default     = false
}

variable "project" {
  type        = string
  description = "Project that these resources are supporting."
}

variable "rate_limit_rules" {
  type = map(object({
    name     = optional(string, null)
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
    error_message = <<-EOT
      Invalid request policy. See
      https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html
      EOT
  }
}

variable "subdomain" {
  type        = string
  description = "Subdomain for the distribution. Defaults to the environment."
  default     = null
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

variable "upload_rules_capacity" {
  type        = number
  description = <<-EOT
    Capacity for the upload rules group. Attempts to determine the capacity if
    left empty.
    EOT
  default     = null
}

variable "use_custom_origin" {
  type        = bool
  description = <<-EOT
    Use a custom origin configuration instead of an ALB origin. When set to
    `true`, a custom origin is used and `origin_alb_arn` is not required; when
    set to `false`, an ALB is used and `origin_alb_arn` must be set.
    EOT
  default     = false
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
  description = <<-EOT
    Priority for the webhooks rule group. By default, an attempt is made to
    place it before other rules that block traffic.
    EOT
  default     = null
}

variable "webhook_rules_capacity" {
  type        = number
  description = <<-EOT
    Capacity for the webhook rules group. Attempts to determine the capacity if
    left empty.
    EOT
  default     = null
}
