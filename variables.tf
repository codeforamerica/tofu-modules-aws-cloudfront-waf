variable "domain" {
  type        = string
  description = "Domain used for this deployment."
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
