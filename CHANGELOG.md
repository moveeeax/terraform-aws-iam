# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `inline_policies` (policy name => JSON) embeds inline policies in the role
  through `aws_iam_role_policy`.
- `policy_documents` (key => JSON) creates customer-managed policies named
  `<role name>-<key>` under the role's path and attaches them to the role.
- Outputs `inline_policy_names` and `policy_arns`.
- Both inputs default to `{}`, so existing roles plan unchanged.

## [1.1.0] - 2026-11-05

### Added

- Validate the role `name` and `path` at plan time.
- `force_detach_policies` input.

### Changed

- CI: move actions to their node24 majors and pin tool versions.

## [1.0.0] - 2026-07-26

Initial release (`v0.1.0` points at the same commit).

[Unreleased]: https://github.com/moveeeax/terraform-aws-iam/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/moveeeax/terraform-aws-iam/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/moveeeax/terraform-aws-iam/releases/tag/v1.0.0
