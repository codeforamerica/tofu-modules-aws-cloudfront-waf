locals {
  fqdn      = join(".", compact([local.subdomain, var.domain]))
  hosted_zone_id    = var.hosted_zone_id == null ? data.aws_route53_zone.domain["this"].zone_id : var.hosted_zone_id
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
