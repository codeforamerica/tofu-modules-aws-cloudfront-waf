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

  # Make sure we generate a new suffix with every run.
  keepers = {
    first = timestamp()
  }
}

resource "random_id" "upload_suffix" {
  keepers = {
    # Generate a new id each time we update the rule group.
    group_id = aws_wafv2_rule_group.uploads["this"].arn
  }

  byte_length = 8
}
