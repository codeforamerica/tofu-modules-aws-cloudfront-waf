locals {
  fqdn      = join(".", compact([local.subdomain, var.domain]))
  subdomain = var.subdomain != null ? var.subdomain : var.environment
  # If an origin ALB ARN is provided, use its DNS name; otherwise, use the
  # provided origin domain or construct one.
  origin_domain = (var.origin_alb_arn != null
    ? data.aws_lb.origin["this"].dns_name
    : (var.origin_domain != "" ? var.origin_domain : join(".", compact(["origin", local.subdomain, var.domain])))
  )
  prefix = "${var.project}-${var.environment}"
  tags   = merge(var.tags, { domain : local.fqdn })
}
