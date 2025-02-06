resource "aws_cloudfront_distribution" "waf" {
  enabled         = true
  comment         = "Pass traffic through WAF before sending to the origin."
  is_ipv6_enabled = true
  aliases         = ["${local.subdomain}.${var.domain}"]
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

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_keepalive_timeout = 5
      origin_protocol_policy   = "https-only"
      origin_read_timeout      = 30
      origin_ssl_protocols     = ["TLSv1.2"]
    }
  }

  logging_config {
    include_cookies = false
    bucket          = var.log_bucket
    prefix          = "cloudfront/${local.subdomain}.${var.domain}"
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
    # acm_certificate_arn      = aws_acm_certificate.subdomain.arn
    acm_certificate_arn      = var.certificate_imported ? data.aws_acm_certificate.imported["this"].arn : aws_acm_certificate.subdomain.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = local.tags
}

resource "aws_wafv2_web_acl" "waf" {
  name        = local.prefix
  description = "Web application firewall rules for ${var.project}."
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # For each IP set rule, create a rule with the appropriate action.
  # TODO: Move these rules to their own group.
  dynamic "rule" {
    for_each = var.ip_set_rules
    content {
      name     = rule.value.name != "" ? rule.value.name : "${local.prefix}-${rule.key}"
      priority = rule.value.priority != null ? rule.value.priority : index(var.ip_set_rules, rule.key)

      action {
        dynamic "allow" {
          for_each = rule.value.action == "allow" ? [true] : []
          content {}
        }

        dynamic "block" {
          for_each = rule.value.action == "block" ? [true] : []
          content {}
        }

        dynamic "count" {
          for_each = rule.value.action == "count" ? [true] : []
          content {}
        }
      }

      statement {
        ip_set_reference_statement {
          arn = rule.value.arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.prefix}-waf-ip-${rule.key}"
        sampled_requests_enabled   = true
      }
    }
  }

  # Attach the webhooks rule group to the WAF, if one was created.
  dynamic "rule" {
    for_each = length(var.webhooks) > 0 ? [true] : []

    content {
      name     = "${local.prefix}-waf-webhooks"
      priority = var.webhooks_priority != null ? var.webhooks_priority : length(var.ip_set_rules)

      override_action {
        dynamic "none" {
          for_each = var.passive ? [] : [true]
          content {}
        }

        dynamic "count" {
          for_each = var.passive ? [true] : []
          content {}
        }
      }

      statement {
        rule_group_reference_statement {
          arn = aws_wafv2_rule_group.webhooks["this"].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.prefix}-waf-webhooks"
        sampled_requests_enabled   = true
      }
    }
  }

  # For each rate-limiting rule, create a rule with the appropriate action.
  # TODO: Move these rules to their own group.
  dynamic "rule" {
    for_each = var.rate_limit_rules
    content {
      name     = rule.value.name != "" ? rule.value.name : "${local.prefix}-rate-${rule.key}"
      priority = rule.value.priority != null ? rule.value.priority : index(var.ip_set_rules, rule.key) + length(var.ip_set_rules) + 1

      action {
        dynamic "allow" {
          for_each = rule.value.action == "allow" ? [true] : []
          content {}
        }

        dynamic "block" {
          for_each = rule.value.action == "block" ? [true] : []
          content {}
        }

        dynamic "count" {
          for_each = rule.value.action == "count" ? [true] : []
          content {}
        }
      }

      statement {
        rate_based_statement {
          aggregate_key_type    = "IP"
          evaluation_window_sec = rule.value.window
          limit                 = rule.value.limit
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.prefix}-waf-rate-${rule.key}"
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 200

    override_action {
      dynamic "none" {
        for_each = var.passive ? [] : [true]
        content {}
      }

      dynamic "count" {
        for_each = var.passive ? [true] : []
        content {}
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.prefix}-waf-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 300

    override_action {
      dynamic "none" {
        for_each = var.passive ? [] : [true]
        content {}
      }

      dynamic "count" {
        for_each = var.passive ? [true] : []
        content {}
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # If a set of upload paths have been provided, override the action for
        # the body size and cross-site scripting (XSS) rules. We'll create a
        # custom rule that will exempt the provided paths.
        dynamic "rule_action_override" {
          for_each = length(var.upload_paths) > 0 ? [true] : []

          content {
            name = "SizeRestrictions_BODY"

            action_to_use {
              count {}
            }
          }
        }

        dynamic "rule_action_override" {
          for_each = length(var.upload_paths) > 0 ? [true] : []

          content {
            name = "CrossSiteScripting_BODY"

            action_to_use {
              count {}
            }
          }
        }

        dynamic "rule_action_override" {
          for_each = length(var.upload_paths) > 0 ? [true] : []

          content {
            name = "GenericLFI_BODY"

            action_to_use {
              count {}
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.prefix}-waf-common-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 400

    override_action {
      dynamic "none" {
        for_each = var.passive ? [] : [true]
        content {}
      }

      dynamic "count" {
        for_each = var.passive ? [true] : []
        content {}
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.prefix}-waf-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 500

    override_action {
      dynamic "none" {
        for_each = var.passive ? [] : [true]
        content {}
      }

      dynamic "count" {
        for_each = var.passive ? [true] : []
        content {}
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"

        # If a set of upload paths have been provided, override the action for
        # the SQL injection rule. We'll create a custom rule that will exempt
        # the provided paths.
        dynamic "rule_action_override" {
          for_each = length(var.upload_paths) > 0 ? [true] : []

          content {
            name = "SQLi_BODY"

            action_to_use {
              count {}
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.prefix}-waf-sqli"
      sampled_requests_enabled   = true
    }
  }

  dynamic "rule" {
    for_each = length(var.upload_paths) > 0 ? [true] : []

    content {
      name     = "${local.prefix}-waf-upload-paths"
      priority = 550

      override_action {
        dynamic "none" {
          for_each = var.passive ? [] : [true]
          content {}
        }

        dynamic "count" {
          for_each = var.passive ? [true] : []
          content {}
        }
      }

      statement {
        rule_group_reference_statement {
          arn = aws_wafv2_rule_group.uploads["this"].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.prefix}-waf-upload-rules"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = local.tags
}

resource "aws_wafv2_web_acl_logging_configuration" "waf" {
  log_destination_configs = [var.log_group]
  resource_arn            = aws_wafv2_web_acl.waf.arn
}
