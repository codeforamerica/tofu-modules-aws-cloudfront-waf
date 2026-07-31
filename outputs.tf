output "application_integration_url" {
  description = <<-EOT
    URL for the AWS WAF application integration SDK (CAPTCHA/Challenge JavaScript
    API). Embed the challenge.js or jsapi.js script from this URL to mint tokens
    in the browser.
    EOT
  value       = aws_wafv2_web_acl.waf.application_integration_url
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name (for example d111111abcdef8.cloudfront.net)."
  value       = aws_cloudfront_distribution.waf.domain_name
}

output "distribution_hosted_zone_id" {
  description = "Route53 hosted zone ID for CloudFront alias records."
  value       = aws_cloudfront_distribution.waf.hosted_zone_id
}

output "distribution_id" {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.waf.id
}
