locals {
  fqdn      = join(".", compact([local.subdomain, var.domain]))
  subdomain = var.subdomain != null ? var.subdomain : var.environment
  prefix    = join("-", compact([var.project, var.environment]))
  tags      = merge(var.tags, { domain : local.fqdn })

  # When using a custom origin, use the provided domain or construct one.
  # Otherwise, use the DNS name of the origin ALB.
  origin_domain = (var.use_custom_origin
    ? coalesce(var.origin_domain, join(".", compact(["origin", local.subdomain, var.domain])))
    : data.aws_lb.origin["this"].dns_name
  )
}
