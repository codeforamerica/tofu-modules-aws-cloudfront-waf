resource "aws_wafv2_web_acl" "waf" {
  name        = local.prefix
  description = "Web application firewall rules for ${var.project}."
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  data_protection_config {
    dynamic "data_protection" {
      for_each = var.redacted_headers

      content {
        action = data_protection.value
        exclude_rule_match_details = false
        exclude_rate_based_details = false

        field {
          field_type = "SINGLE_HEADER"
          field_keys = [data_protection.key]
        }
      }
    }
  }

  # For each IP set rule, create a rule with the appropriate action.
  # TODO: Move these rules to their own group.
  dynamic "rule" {
    for_each = var.ip_set_rules
    content {
      name     = coalesce(rule.value.name, join("-", [local.prefix, "ip", rule.key]))
      priority = rule.value.priority != null ? rule.value.priority : index(keys(var.ip_set_rules), rule.key)

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
      name     = coalesce(rule.value.name, join("-", [local.prefix, "rate", rule.key]))
      priority = rule.value.priority != null ? rule.value.priority : index(keys(var.rate_limit_rules), rule.key) + length(var.ip_set_rules) + 1

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
