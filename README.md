# terraform-aws-iam

Terraform module that manages an [AWS IAM](https://aws.amazon.com/iam/) role.
It creates a single role from a caller-supplied trust policy and attaches any
number of managed policies, keeping role creation and permission attachment in
one place.

## Usage

```hcl
module "iam" {
  source = "github.com/moveeeax/terraform-aws-iam"

  name               = "app-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ]

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Trust policy guardrails

The trust policy decides who can become the role, so the module refuses two
documents that are almost never what the caller meant:

* **A wildcard principal with no `Condition`.** `"Principal": "*"` or
  `"Principal": {"AWS": "*"}` on an `Allow` statement lets *any* AWS account
  assume the role. Add a `Condition` that narrows it — `aws:PrincipalOrgID`,
  `aws:PrincipalArn`, `sts:ExternalId` — or name the principals explicitly.
* **An OIDC principal that does not pin `:sub`.** A GitHub Actions trust policy
  that only checks `:aud` is assumable by *every* repository on GitHub. Pin the
  subject as narrowly as the workflow allows:

  ```json
  {
    "Effect": "Allow",
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Principal": {
      "Federated": "arn:aws:iam::111122223333:oidc-provider/token.actions.githubusercontent.com"
    },
    "Condition": {
      "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
      "StringLike":   { "token.actions.githubusercontent.com:sub": "repo:example-org/example-repo:*" }
    }
  }
  ```

`Deny` statements are left alone — a wildcard principal there is a restriction,
not a grant. Cross-account trust is not blocked, but if the other account is a
third party you should still require an `sts:ExternalId` condition.

Set `permissions_boundary` to cap what the role can do no matter which policies
end up attached to it.

## Testing

```
terraform test
```

The suite mocks the AWS provider, so it needs no credentials and no network
beyond `terraform init`. Provider mocking requires Terraform (or OpenTofu)
`>= 1.7`; that is a test-only requirement and the module itself still supports
`>= 1.5`.

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| aws       | >= 5.0   |

## Inputs

| Name                    | Description                                                       | Type           | Default   | Required |
|-------------------------|-------------------------------------------------------------------|----------------|-----------|:--------:|
| `name`                  | Name of the IAM role. 1-64 characters, matching `[A-Za-z0-9_+=,.@-]+`. | `string` | n/a  |   yes    |
| `assume_role_policy`    | JSON trust policy for the role. Validated — see [guardrails](#trust-policy-guardrails). | `string` | n/a |   yes    |
| `description`           | Description of the IAM role.                                     | `string`       | `"Managed by Terraform"` | no |
| `path`                  | Path under which to create the role. Must start and end with `/`. | `string`       | `"/"`     |    no    |
| `permissions_boundary`  | ARN of the policy used as the role's permissions boundary.      | `string`       | `null`    |    no    |
| `max_session_duration`  | Maximum session duration in seconds.                            | `number`       | `3600`    |    no    |
| `managed_policy_arns`   | List of managed policy ARNs to attach.                          | `list(string)` | `[]`      |    no    |
| `force_detach_policies` | Force-detach attached policies when the role is destroyed.      | `bool`         | `false`   |    no    |
| `tags`                  | Tags applied to the role.                                       | `map(string)`  | `{}`      |    no    |

## Outputs

| Name        | Description                                     |
|-------------|-------------------------------------------------|
| `id`        | Name of the role.                               |
| `arn`       | ARN of the role.                                |
| `name`      | Name of the role.                               |
| `unique_id` | Stable and unique string identifying the role.  |

## License

[MIT](LICENSE)
