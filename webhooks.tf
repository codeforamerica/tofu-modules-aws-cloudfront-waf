resource "aws_wafv2_rule_group" "webhooks" {
  for_each = length(var.webhooks) > 0 ? toset(["this"]) : toset([])

  name_prefix = "${local.prefix}-webhooks-"
  scope       = "CLOUDFRONT"
  capacity    = var.webhook_rules_capacity == null ? 50 : var.webhook_rules_capacity

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
      priority = index(keys(var.webhooks), rule.key)

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

      # Check if the path matches any of the webhook paths.
      statement {
        # OR statements require at least two child statements. If we only have
        # a single path, we can use a single byte match statement.
        dynamic "byte_match_statement" {
          for_each = length(rule.value.paths) == 1 ? [true] : []

          content {
            positional_constraint = rule.value.paths[0].constraint
            search_string         = rule.value.paths[0].path

            field_to_match {
              uri_path {}
            }

            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }

        # If there are more than one path, we'll evaluate them each in an OR
        # statement.
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

  # Define the rules to check additional criteria before allowing the request.
  dynamic "rule" {
    for_each = var.webhooks

    content {
      name     = "${local.prefix}-webhooks-${rule.key}"
      priority = index(keys(var.webhooks), rule.key) + length(keys(var.webhooks))

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

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.prefix}-webhooks-${rule.key}"
        sampled_requests_enabled   = true
      }

      statement {
        # If there are no additional criteria, just create the label match
        # statement.
        dynamic "label_match_statement" {
          for_each = length(rule.value.criteria) == 0 ? [true] : []

          content {
            scope = "LABEL"
            key   = "webhook:${rule.key}"
          }
        }

        # If there are additional criteria, we'll evaluate them each in an AND
        # statement, along with the label match statement.
        dynamic "and_statement" {
          for_each = length(rule.value.criteria) > 0 ? [true] : []

          content {
            statement {
              label_match_statement {
                scope = "LABEL"
                key   = "webhook:${rule.key}"
              }
            }

            dynamic "statement" {
              for_each = rule.value.criteria

              content {
                dynamic "byte_match_statement" {
                  for_each = statement.value.type == "byte" ? [true] : []

                  content {
                    positional_constraint = statement.value.constraint
                    search_string         = statement.value.value

                    field_to_match {
                      dynamic "uri_path" {
                        for_each = statement.value.field == "uri" ? [true] : []
                        content {}
                      }

                      dynamic "single_header" {
                        for_each = statement.value.field == "header" ? [true] : []
                        content {
                          name = statement.value.name
                        }
                      }
                    }

                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }

                dynamic "size_constraint_statement" {
                  for_each = statement.value.type == "size" ? [true] : []

                  content {
                    comparison_operator = statement.value.constraint
                    size                = tonumber(statement.value.value)

                    field_to_match {
                      dynamic "uri_path" {
                        for_each = statement.value.field == "uri" ? [true] : []
                        content {}
                      }

                      dynamic "single_header" {
                        for_each = statement.value.field == "header" ? [true] : []
                        content {
                          name = statement.value.name
                        }
                      }
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

  lifecycle {
    create_before_destroy = true
  }
}
