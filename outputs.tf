output "application_integration_url" {
  description = <<-EOT
    URL for the AWS WAF application integration SDK (CAPTCHA/Challenge JavaScript
    API). Embed the challenge.js or jsapi.js script from this URL to mint tokens
    in the browser.
    EOT
  value       = aws_wafv2_web_acl.waf.application_integration_url
}
