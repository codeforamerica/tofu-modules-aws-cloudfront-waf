resource "aws_wafv2_rule_group" "uploads" {
  name = "${local.prefix}-waf-allow-uploads"
  scope = "CLOUDFRONT"
  capacity = 2

  rule {
    name     = "${local.prefix}-waf-request-body-size"
    priority = 1

    action {
      block {}
    }

    statement {
      and_statement {
        statement {
          label_match_statement {
            key   = "awswaf:managed:aws:core-rule-set:SizeRestrictions_Body"
            scope = "LABEL"
          }
        }

        statement {
          # If we have more than one upload path, we need to create an OR
          # statement to match on any of the paths.
          dynamic "or_statement" {
            for_each = length(var.upload_paths) > 1 ? [true] : []

            content {
              dynamic "statement" {
                for_each = var.upload_paths

                content {
                  not_statement {
                    statement {
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

          #  If we only have one path, we need to use a single NOT statement
          #  because OR statements require at least two statements.
          dynamic "not_statement" {
            for_each = length(var.upload_paths) == 1 ? var.upload_paths : []

            content {
              statement {
                byte_match_statement {
                  positional_constraint = not_statement.value.constraint
                  search_string         = not_statement.value.path

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

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "gyr-demo-waf-request-body-size"
      sampled_requests_enabled   = true
    }
  }
}
