resource "aws_route53_record" "subdomain" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = local.fqdn
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.waf.domain_name
    zone_id                = aws_cloudfront_distribution.waf.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_acm_certificate" "subdomain" {
  # Specify the name rather than referencing the resource directly. This allows
  # us to create the certificate before the DNS record exists.
  domain_name       = local.fqdn
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.subdomain.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 300
  type            = each.value.type
  zone_id         = data.aws_route53_zone.domain.zone_id
}

resource "aws_acm_certificate_validation" "validation" {
  certificate_arn = aws_acm_certificate.subdomain.arn
  validation_record_fqdns = [
    for record in aws_route53_record.validation : record.fqdn
  ]
}

resource "aws_lb_listener_certificate" "origin" {
  # If the origin is an ALB, we need to attach our certificate to its listener
  # so that it properly negotiates TLS with the CloudFront "Host" header.
  for_each = var.use_custom_origin ? toset([]) : toset(["this"])

  listener_arn    = data.aws_lb_listener.origin["this"].arn
  certificate_arn = aws_acm_certificate.subdomain.arn
}
