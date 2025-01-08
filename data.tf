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
