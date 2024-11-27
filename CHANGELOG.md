# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.4.1 (2024-11-27)

### Fix

- Exclude files uploads from `CrossSiteScripting_BODY` and `SQLi_BODY` rules. (#14)

## 1.4.0 (2024-11-15)

### Feat

- Exempt upload paths from body size constraints. (#12)

## 1.3.0 (2024-11-14)

### Feat

- Allow custom headers to add to the request. (DEV-12) (#10)

## 1.2.0 (2024-10-29)

### Feat

- Added rate limiting configuration. (#8)

### Fix

- Updated metric names.

## 1.1.0 (2024-10-18)

### Feat

- Allow WAF to be put into passive mode. (#4)

## 1.0.0 (2024-10-11)

### Feat

- Initial release. (#1)
