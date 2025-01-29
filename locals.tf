locals {
  fqdn          = "${local.subdomain}.${var.domain}"
  subdomain     = var.subdomain == "" ? var.environment : var.subdomain
  origin_domain = var.origin_domain == "" ? "origin.${local.subdomain}.${var.domain}" : var.origin_domain
  prefix        = "${var.project}-${var.environment}"
  tags          = merge(var.tags, { domain : "${local.subdomain}.${var.domain}" })
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}
