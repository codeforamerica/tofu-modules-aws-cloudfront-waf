# CloudFront's own redirect-to-https response (issued before the request ever
# reaches the origin) is only covered by this policy, not by headers the
# origin sets. Managed-SimpleCORS doesn't include security headers, so that
# redirect was shipping with no Strict-Transport-Security, X-Frame-Options,
# X-Content-Type-Options, Content-Security-Policy, or Cache-Control header.
# Every header below is `override = false` so the origin's own value (e.g.
# Rails' `force_ssl` and CSP config) always wins for responses that do reach
# it; these settings only fill the gap for responses CloudFront generates
# itself.
resource "aws_cloudfront_response_headers_policy" "policy" {
  name = "${local.prefix}-response-headers"

  cors_config {
    access_control_allow_credentials = false
    origin_override                  = false

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD"]
    }

    access_control_allow_origins {
      items = ["*"]
    }
  }

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 63072000
      include_subdomains         = true
      preload                    = true
      override                   = false
    }

    frame_options {
      frame_option = "SAMEORIGIN"
      override     = false
    }

    content_type_options {
      override = false
    }

    content_security_policy {
      content_security_policy = "default-src 'none'; frame-ancestors 'none'"
      override                = false
    }
  }

  custom_headers_config {
    items {
      header   = "Cache-Control"
      value    = "no-store"
      override = false
    }
  }
}

resource "aws_cloudfront_distribution" "waf" {
  enabled         = true
  comment         = "Pass traffic through WAF before sending to the origin."
  is_ipv6_enabled = true
  aliases         = local.aliases
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
    response_headers_policy_id = aws_cloudfront_response_headers_policy.policy.id

    viewer_protocol_policy = "redirect-to-https"
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.redirect_paths

    content {
      path_pattern           = ordered_cache_behavior.value.path_pattern
      allowed_methods        = ["GET", "HEAD"]
      cached_methods         = ["GET", "HEAD"]
      target_origin_id       = local.origin_domain
      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 0
      max_ttl                = 0
      cache_policy_id        = data.aws_cloudfront_cache_policy.policy.id

      function_association {
        event_type   = "viewer-request"
        function_arn = ordered_cache_behavior.value.function_arn
      }
    }
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
    minimum_protocol_version = var.minimum_protocol_version
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
