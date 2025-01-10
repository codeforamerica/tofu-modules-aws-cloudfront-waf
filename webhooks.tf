resource "aws_wafv2_rule_group" "webhooks" {
  for_each = length(var.webhooks) > 0 ? toset(["this"]) : toset([])

  name     = "${local.prefix}-webhooks"
  scope    = "CLOUDFRONT"
  capacity = 50

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.prefix}-webhooks"
    sampled_requests_enabled   = true
  }

  # Define the rules to match the paths and apply a label to matching requests.
  dynamic "rule" {
    for_each = var.webhooks

    content {
      name     = "${local.prefix}-webhooks-${rule.key}-label"
      priority = index(var.webhooks, rule.key)

      rule_label {
        name = "webhook:${rule.key}"
      }

      action {
        count {}
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.prefix}-webhooks-${rule.key}-label"
        sampled_requests_enabled   = true
      }

      statement {
        # Check if the path matches any of the webhook paths.
        dynamic "or_statement" {
          for_each = length(rule.value.paths) > 1 ? [true] : []

          content {
            dynamic "statement" {
              for_each = rule.value.paths

              content {
                byte_match_statement {
                  positional_constraint = statement.value.constraint
                  search_string         = statement.value.path

                  field_to_match {
                    uri_path {}
                  }

                  text_transformation {
                    priority = 0
                    type     = "NONE"
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
