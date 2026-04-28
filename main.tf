resource "aws_cloudfront_distribution" "waf" {
  enabled         = true
  comment         = "Pass traffic through WAF before sending to the origin."
  is_ipv6_enabled = true
  aliases         = [local.fqdn]
  price_class     = "PriceClass_100"
  web_acl_id      = aws_wafv2_web_acl.waf.arn

  origin {
    domain_name         = local.origin_domain
    origin_id           = local.origin_domain
    connection_attempts = 3
    connection_timeout  = 10

    dynamic "custom_header" {
      for_each = var.custom_headers

      content {
        name  = custom_header.key
        value = custom_header.value
      }
    }

    dynamic "custom_origin_config" {
      for_each = var.use_custom_origin ? toset(["this"]) : toset([])

      content {
        http_port                = 80
        https_port               = 443
        origin_keepalive_timeout = 5
        origin_protocol_policy   = "https-only"
        origin_read_timeout      = 30
        origin_ssl_protocols     = ["TLSv1.2"]
      }
    }

    dynamic "vpc_origin_config" {
      for_each = var.use_custom_origin ? toset([]) : toset(["this"])

      content {
        origin_keepalive_timeout = 5
        origin_read_timeout      = 30
        vpc_origin_id            = aws_cloudfront_vpc_origin.this["this"].id
      }
    }
  }

  logging_config {
    include_cookies = false
    bucket          = var.log_bucket
    prefix          = "cloudfront/${local.fqdn}"
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.origin_domain
    compress         = true
    default_ttl      = 0
    max_ttl          = 0
    min_ttl          = 0

    cache_policy_id            = data.aws_cloudfront_cache_policy.policy.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.policy.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.policy.id

    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_imported ? data.aws_acm_certificate.imported["this"].arn : aws_acm_certificate.subdomain.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = merge(local.tags, { Name : local.fqdn })
}

resource "terraform_data" "prefix" {
  input = local.prefix
}

resource "terraform_data" "origin_alb" {
  input = var.origin_alb_arn
}

resource "aws_cloudfront_vpc_origin" "this" {
  for_each = var.use_custom_origin ? toset([]) : toset(["this"])

  vpc_origin_endpoint_config {
    name                   = local.prefix
    arn                    = var.origin_alb_arn
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "match-viewer"

    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }

  tags = local.tags

  lifecycle {
    # Some changes don't force a replacement, but will fail if the origin is in
    # use. We want to force a replacement so that the origin is updated
    # properly.
    create_before_destroy = true
    replace_triggered_by  = [terraform_data.prefix, terraform_data.origin_alb]
  }
}
