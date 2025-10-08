# CloudFront WAF Module

[![Main Checks][badge-checks]][code-checks] [![GitHub Release][badge-release]][latest-release]

This module creates a CloudFront [distribution] that passes traffic through a
Web Application Firewall (WAF) _without_ caching.

## Usage

Add this module to your `main.tf` (or appropriate) file and configure the inputs
to match your desired configuration. For example, to create a new distribution
`my-project.org` that points to `origin.my-project.org`, you could use:

```hcl
module "cloudfront_waf" {
  source = "github.com/codeforamerica/tofu-modules-aws-cloudfront-waf?ref=1.9.0"

  project     = "my-project"
  environment = "dev"
  domain      = "my-project.org"
  log_bucket  = module.logging.bucket
}
```

Make sure you re-run `tofu init` after adding the module to your configuration.

```bash
tofu init
tofu plan
```

To update the source for this module, pass `-upgrade` to `tofu init`:

```bash
tofu init -upgrade
```

## Rules

The WAF is configured with the following managed rules groups. The priorities of
these rules are spaced out to allow for custom rules to be inserted between.

| Rule Group Name                                       | Priority | Description                                           |
|-------------------------------------------------------|----------|-------------------------------------------------------|
| [AWSManagedRulesAmazonIpReputationList][rules-ip-rep] | 200      | Protects against IP addresses with a poor reputation. |
| [AWSManagedRulesCommonRuleSet][rules-common]          | 300      | Protects against common threats.                      |
| [AWSManagedRulesKnownBadInputsRuleSet][rules-inputs]  | 400      | Protects against known bad inputs.                    |
| [AWSManagedRulesSQLiRuleSet][rules-sqli]              | 500      | Protects against SQL injection attacks.               |

## SSL Certificates

By default, this module will use [AWS Certificate Manager][acm] (ACM) to manage
certificates for the distribution. It uses [Route 53][route53] to validate the
certificate.

If you require an [extended validation][evssl] (EV) or other specialized
certificate, you can [import your certificate][acm-import] into ACM the
appropriate `project` and `environment` tags, and set the `certificate_imported`
variable to `true`.

> [!IMPORTANT]
> If you have more than one imported certificate that matches the search
> criteria, the most recent certificate will be used.

If your imported certificate uses a different domain than your distribution
(e.g. your certificate does not include the subdomain), you can specify the
`certificate_domain` variable to match the certificate's domain.

For example, to use an imported certificate for `my-project.org` with a
distribution at `www.my-project.org`, you could use the following:

> [!NOTE]
> In this case, when the certificate was imported, the `project` tag would have
> been set to `my-project` and the `environment` tag would have been set to
> `dev`.

```hcl
module "cloudfront_waf" {
  source = "github.com/codeforamerica/tofu-modules-aws-cloudfront-waf?ref=1.9.0"

  project     = "my-project"
  environment = "dev"
  domain      = "my-project.org"
  subdomain   = "www"
  log_bucket  = module.logging.bucket

  certificate_imported = true
  certificate_domain   = "my-project.org"
}
```

## Capacity

AWS measures the capacity of a WAF and it's rules in [Web ACL Capacity
Units][wcus] (WCU). A Web ACL can not contain more rules than it has capacity
for. Further, when we create a rule group, that rule group must have a capacity
less than or equal to the capacity of the rules within it.

When creating a rule group, such as for [uploads][upload_paths] and [webhooks],
this module will attempt to determine an appropriate capacity. This is not
always accurate and can lead to errors when applying the configuration if the
number is too low.

> [!TIP]
> If you encounter a capacity error during apply, such as the following:
>
> > WAFInvalidParameterException: Error reason: You exceeded the capacity limit
> > for a rule group or web ACL.
>
> this is a good indication that you may need to set the capacity manually. At
> the end of this message you should see something like:
>
> > field: RULE_GROUP, parameter: **92**
>
> In this case, the minimum capacity for the rule group should be `92`.

In order to override the capacity for a rule group, you can specify the WCUs
through an appropriate variable. For example, to set the capacity for the
`webhooks` rule group to `100`, you could use:

```hcl
webhooks_priority = 100
```

## Inputs

| Name                   | Description                                                                                                               | Type           | Default       | Required |
|------------------------|---------------------------------------------------------------------------------------------------------------------------|----------------|---------------|----------|
| domain                 | Primary domain for the distribution. The hosted zone for this domain should be in the same account.                       | `string`       | n/a           | yes      |
| log_bucket             | Domain name of the S3 bucket to send logs to.                                                                             | `string`       | n/a           | yes      |
| log_group              | CloudWatch log group to send WAF logs to.                                                                                 | `string`       | n/a           | yes      |
| project                | Project that these resources are supporting.                                                                              | `string`       | n/a           | yes      |
| certificate_domain     | Domain for the imported certificate, if different from the endpoint. Used in conjunction with `certificate_imported`.     | `string`       | `""`          | no       |
| certificate_imported   | Whether the certificate is imported or managed by ACM.                                                                    | `bool`         | `false`       | no       |
| [custom_headers]       | Custom headers to send to the origin.                                                                                     | `map(string)`  | `{}`          | no       |
| environment            | The environment for the deployment.                                                                                       | `string`       | `"dev"`       | no       |
| [ip_set_rules]         | Custom IP Set rules for the WAF                                                                                           | `map(object)`  | `{}`          | no       |
| [rate_limit_rules]     | Rate limiting configuration for the WAF.                                                                                  | `map(object)`  | `{}`          | no       |
| origin_alb_arn         | ARN of the Application Load Balancer this deployment will point to. If set, `origin_domain` is ignored.                   | `string`       | n/a           | no       |
| origin_domain          | Fully qualified domain name for the origin. Defaults to `origin.${subdomain}.${domain}`.                                  | `string`       | n/a           | no       |
| passive                | Enable passive mode for the WAF, counting all requests rather than blocking.                                              | `bool`         | `false`       | no       |
| request_policy         | Managed request policy to associate with the distribution. See the [managed policies][managed-policies] for valid values. | `string`       | `"AllViewer"` | no       |
| subdomain              | Subdomain for the distribution. Defaults to the environment.                                                              | `string`       | n/a           | no       |
| tags                   | Optional tags to be applied to all resources.                                                                             | `map(string)`  | `{}`          | no       |
| [upload_paths]         | Optional paths to allow uploads to.                                                                                       | `list(object)` | `[]`          | no       |
| upload_rules_capacity  | Capacity for the upload rules group. Attempts to determine the capacity if left empty.                                    | `number`       | `null`        | no       |
| [webhooks]             | Optional map of webhooks that should be allowed through the WAF.                                                          | `map(object)`  | `{}`          | no       |
| webhooks_priority      | Priority for the webhooks rule group. By default, an attempt is made to place it before other rules that block traffic.   | `number`       | `null`        | no       |
| webhook_rules_capacity | Capacity for the webhook rules group. Attempts to determine the capacity if left empty.                                   | `number`       | `null`        | no       |

### custom_headers

> [!NOTE]
> Some headers can not be added to the request. These mostly represent common
> headers and those reserved for specific use cases, such as `Content-Length`
> and `X-Amz-*`. The full list of restricted headers can be found in the
> [CloudFront documentation][cloudfront-headers].

You can add custom headers to the request before passing it on to the origin.
Simply specify the headers you want to add in a map. For example:

```hcl
module "cloudfront_waf" {
  source = "github.com/codeforamerica/tofu-modules-aws-cloudfront-waf?ref=1.9.0"

  project     = "my-project"
  environment = "dev"
  domain      = "my-project.org"
  log_bucket  = module.logging.bucket

  custom_headers = {
    x-custom-header = "my-custom-value"
    x-origin-token  = "my-origin-token"
  }
}
```

### ip_set_rules

To allow or deny traffic based on IP address, you can specify a map of [IP set
rules][ip-rules] to create. You will need to create the IP set in your
configuration, and provide the ARN of the resource. An IP set can be created
with the [`wafv2_ip_set`][wafv2_ip_set] resource.

For example:

```hcl
resource "aws_wafv2_ip_set" "security_scanners" {
  name               = "my-project-staging-security-scanners"
  description        = "Security scanners that are allowed to access the site."
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = [
    "1.2.3.4/32",
    "5.6.7.8/32"
  ]
}

module "cloudfront_waf" {
  source = "github.com/codeforamerica/tofu-modules-aws-cloudfront-waf?ref=1.9.0"

  project     = "my-project"
  environment = "staging"
  domain      = "my-project.org"
  log_bucket  = module.logging.bucket

  ip_set_rules = {
    scanners = {
      name     = "my-project-staging-security-scanners"
      priority = 0
      action   = "allow"
      arn      = aws_wafv2_ip_set.security_scanners.arn
    }
  }
}
```

| Name     | Description                                                                   | Type     | Default   | Required |
|----------|-------------------------------------------------------------------------------|----------|-----------|----------|
| action   | The action to perform.                                                        | `string` | `"allow"` | no       |
| arn      | ARN of the IP set to match on.                                                | `string` | n/a       | yes      |
| name     | Name for this rule. Defaults to `${project}-${environment}-rate-${rule.key}`. | `string` | `""`      | no       |
| priority | Rule priority. Defaults to the rule's position in the map.                    | `number` | `nil`     | no       |

### rate_limit_rules

To rate limit traffic based on IP address, you can specify a map of rate limit
rules to create. The rate limit rules are applied in the order they are defined,
or though the `priority` field.

> [!NOTE]
> Rate limit rules are added after all IP set rules by default. Use `priority`
> to order your rules if you need more control.

For example, to rate limit requests to 300 over a 5-minute period:

```hcl
module "cloudfront_waf" {
  source = "github.com/codeforamerica/tofu-modules-aws-cloudfront-waf?ref=1.9.0"

  project     = "my-project"
  environment = "staging"
  domain      = "my-project.org"
  log_bucket  = module.logging.bucket

  rate_limit_rules = {
    limit = {
      name   = "my-project-staging-rate-limit"
      action = "block"
      limit  = 500
      window = 500
    }
  }
}
```

| Name     | Description                                                                             | Type     | Default   | Required |
|----------|-----------------------------------------------------------------------------------------|----------|-----------|----------|
| action   | The action to perform.                                                                  | `string` | `"block"` | no       |
| name     | Name for this rule. Defaults to `${project}-${environment}-rate-${rule.key}`.           | `string` | `""`      | no       |
| limit    | The number of requests allowed within the window. Minimum value of 10.                  | `number` | `10`      | no       |
| priority | Rule priority. Defaults to the rule's position in the map + the number of IP set rules. | `number` | `nil`     | no       |
| window   | Number of seconds to limit requests in. Options are: 60, 120, 300, 600                  | `number` | `60`      | no       |

### upload_paths

The [AWSManagedRulesCommonRuleSet][rules-common] rule group, by default, will
block requests over 8KB in size, via the `SizeRestrictions_BODY` rule.
Additionally, [random characters in the file metadata][file-false-positives] can
trigger the `CrossSiteScripting_BODY` and `SQLi_BODY` rules. We can override
this to exclude certain paths that are used for file uploads.

The new rule created by this override will be given the priority of `550`, to
ensure it comes after the common and SQLi rule sets.

> [!NOTE]
> The `constraint` field defines how the path is matched. Valid values are:
> `EXACTLY`, `STARTS_WITH`, `ENDS_WITH`, `CONTAINS`, `CONTAINS_WORD`.
>
> For more information on how these are applied, see the [AWS
> documentation][constraints].

```hcl
module "cloudfront_waf" {
  source = "github.com/codeforamerica/tofu-modules-aws-cloudfront-waf?ref=1.9.0"

  project     = "my-project"
  environment = "staging"
  domain      = "my-project.org"
  log_bucket  = module.logging.bucket

  upload_paths = [
    {
      constraint = "ENDS_WITH"
      path       = "/documents"
    },
    {
      constraint = "EXACTLY"
      path       = "/upload"
    }
  ]
}
```

### webhooks

> [!CAUTION]
> The WAF is only able to verify these request at a surface level. It is not
> a replacement for proper input validation and security practices in your
> application.

If your application has webhooks, the external services that call them may be
rate limited or otherwise blocked by the WAF. To avoid this, you can specify a
map of webhooks that should be allowed through the WAF.

For each webhook, you can specify the paths that should be exempt from the WAF.
Rather than simply allowing all request to these paths, you can specify a set of
conditions that must be met for the request to be allowed through.

> [!NOTE]
> Requests to webhooks paths _are not blocked_ if they fail to meet the criteria
> for the webhook. Rather, they continue to be evaluated by the remaining rules
> as normal.

```hcl
module "cloudfront_waf" {
  source = "github.com/codeforamerica/tofu-modules-aws-cloudfront-waf?ref=1.9.0"

  project     = "my-project"
  environment = "staging"
  domain      = "my-project.org"
  log_bucket  = module.logging.bucket

  webhooks = {
    twilio = {
      paths = [{
          constraint = "EXACTLY"
          path      = "/incoming_text_messages"
        },
        {
          constraint = "STARTS_WITH"
          path      = "/outgoing_text_messages/"
      }]
      # Make sure the `x-twilio-signature` header is present and not empty.
      criteria = [{
        type       = "size"
        constraint = "GT"
        field      = "header"
        name       = "x-twilio-signature"
        value      = "0"
      }]
      action = "allow"
    }
  }
}
```

The webhooks should be keyed by the service or function that they are associated
with. One or more `paths` are required for each webhook, and each path can
include a different `constraint` (see [upload_paths] for more information on
path matching).

For each webhook, you can optionally specify one or more `criteria` that must be
met for the request to be allowed. This can be used to check for specific
headers, query parameters, or other request attributes that are expected for a
valid request. If not criteria are specified, any requests matching the paths
will be allowed through.

| Name                          | Description                                                                                           | Type           | Default   | Required |
|-------------------------------|-------------------------------------------------------------------------------------------------------|----------------|-----------|----------|
| [paths][webhooks.paths]       | The webhook paths for the service or function.                                                        | `list(object)` | n/a       | yes      |
| action                        | The action to apply to requests matching the criteria. Valid values are `allow`, `block`, and `count`. | `string`       | `"allow"` | no       |
| [criteria][webhooks.criteria] | Constraint to apply when testing for the path                                                         | `list(object)` | `[]`      | no       |

#### criteria

| Name       | Description                                                                                                                                                              | Type     | Default | Required  |
|------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|---------|-----------|
| field      | The field to apply the constraint to. Supported values are `header`, and `uri`.                                                                                          | `string` | n/a     | yes       |
| type       | The type of statement for this criteria. Supported values are `byte` and `size`.                                                                                         | `string` | n/a     | yes       |
| value      | The comparison value for the constraint.                                                                                                                                 | `string` | n/a     | yes       |
| constraint | The constraint to apply within the rule. The actual value will be dependent on the `type`. Examples include `STARTS_WITH` for a `byte` statment or `GE` (>=) for `size`. | `string` | `""`    | no        |
| name       | The name of the header to use when `field` is set to `header`.                                                                                                           | `string` | `""`    | dependant |

#### paths

| Name       | Description                                                                                                                              | Type     | Default     | Required |
|------------|------------------------------------------------------------------------------------------------------------------------------------------|----------|-------------|----------|
| path       | The path to match.                                                                                                                       | `string` | n/a         | yes      |
| constraint | The constraint to apply when matching the path. Supported values are `EXACTLY`, `STARTS_WITH`, `ENDS_WITH`, `CONTAINS`, `CONTAINS_WORD`. | `string` | `"EXACTLY"` | no       |

[acm]: https://aws.amazon.com/certificate-manager/
[acm-import]: https://docs.aws.amazon.com/acm/latest/userguide/import-certificate.html
[badge-checks]: https://github.com/codeforamerica/tofu-modules-aws-cloudfront-waf/actions/workflows/main.yaml/badge.svg
[badge-release]: https://img.shields.io/github/v/release/codeforamerica/tofu-modules-aws-cloudfront-waf?logo=github&label=Latest%20Release
[cloudfront-headers]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/add-origin-custom-headers.html#add-origin-custom-headers-denylist
[code-checks]: https://github.com/codeforamerica/tofu-modules-aws-cloudfront-waf/actions/workflows/main.yaml
[constraints]: https://docs.aws.amazon.com/waf/latest/APIReference/API_ByteMatchStatement.html
[custom_headers]: #custom_headers
[distribution]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/distribution-working-with.html
[evssl]: https://cabforum.org/working-groups/server/extended-validation/about/
[file-false-positives]: https://repost.aws/knowledge-center/waf-upload-blocked-files
[ip-rules]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-rule-statement-type-ipset-match.html
[ip_set_rules]: #ip_set_rules
[latest-release]: https://github.com/codeforamerica/tofu-modules-aws-cloudfront-waf/releases/latest
[managed-policies]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html
[rate_limit_rules]: #rate_limit_rules
[route53]: https://aws.amazon.com/route53/
[rules-common]: https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-baseline.html#aws-managed-rule-groups-baseline-crs
[rules-inputs]: https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-baseline.html#aws-managed-rule-groups-baseline-known-bad-inputs
[rules-ip-rep]: https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-ip-rep.html#aws-managed-rule-groups-ip-rep-amazon
[rules-sqli]: https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-use-case.html#aws-managed-rule-groups-use-case-sql-db
[upload_paths]: #upload_paths
[wafv2_ip_set]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_ip_set
[wcus]: https://docs.aws.amazon.com/waf/latest/developerguide/limits.html
[webhooks]: #webhooks
[webhooks.paths]: #paths
[webhooks.criteria]: #criteria
