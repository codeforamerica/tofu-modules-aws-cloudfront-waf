resource "aws_wafv2_rule_group" "uploads" {
  for_each = length(var.upload_paths) > 0 ? toset(["this"]) : toset([])

  name     = "${local.prefix}-waf-allow-uploads-${random_id.upload_suffix.id}"
  scope    = "CLOUDFRONT"
  capacity = 9 * length(var.upload_paths)

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.prefix}-waf-allow-uploads"
    sampled_requests_enabled   = true
  }

  # Block requests based on body size if not in the allowed upload paths.
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
      metric_name                = "${local.prefix}-waf-request-body-size"
      sampled_requests_enabled   = true
    }
  }

  # Block SQL injection requests, unless it was triggered by a file upload.
  rule {
    name     = "${local.prefix}-waf-request-sqli"
    priority = 2

    action {
      block {}
    }

    statement {
      and_statement {
        statement {
          label_match_statement {
            key   = "awswaf:managed:aws:sql-database:SQLi_Body"
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
      metric_name                = "${local.prefix}-waf-request-sqli"
      sampled_requests_enabled   = true
    }
  }

  # Block cross-site scripting (XSS) requests, unless it was triggered by a file
  # upload.
  rule {
    name     = "${local.prefix}-waf-request-xss"
    priority = 3

    action {
      block {}
    }

    statement {
      and_statement {
        statement {
          label_match_statement {
            key   = "awswaf:managed:aws:core-rule-set:CrossSiteScripting_Body"
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
      metric_name                = "${local.prefix}-waf-request-xss"
      sampled_requests_enabled   = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
