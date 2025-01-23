data "aws_acm_certificate" "imported" {
  for_each = var.certificate_imported ? toset(["this"]) : toset([])

  domain      = var.certificate_domain != "" ? var.certificate_domain : local.fqdn
  statuses    = ["ISSUED"]
  types       = ["IMPORTED"]
  most_recent = true

  tags = {
    project     = var.project
    environment = var.environment
  }
}

data "aws_cloudfront_cache_policy" "policy" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "policy" {
  name = "Managed-${var.request_policy}"
}

data "aws_cloudfront_response_headers_policy" "policy" {
  name = "Managed-SimpleCORS"
}

data "aws_route53_zone" "domain" {
  name = var.domain
}
