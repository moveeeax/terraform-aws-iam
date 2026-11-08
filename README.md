# terraform-aws-iam

Terraform module that manages an [AWS IAM](https://aws.amazon.com/iam/) role.
It creates a single role from a caller-supplied trust policy, attaches any
number of managed policies, and can create inline or customer-managed policies
for the role, keeping role creation and permissions in one place.

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

## Role-specific policies

Two inputs cover permissions that belong to this role only, so there is no
need to create an `aws_iam_policy` outside the module and pass its ARN in:

* `inline_policies` embeds policies in the role (`aws_iam_role_policy`). Map
  keys are the policy names. Inline policies are deleted with the role and
  cannot be reused elsewhere. IAM caps the total size of a role's inline
  policies, so large documents fit better in `policy_documents`.
* `policy_documents` creates customer-managed policies (`aws_iam_policy`) and
  attaches them to the role. Each policy is named `<role name>-<key>` under the
  role's `path`, so the same key on two roles does not collide.

```hcl
data "aws_iam_policy_document" "read_bucket" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::example-bucket/*"]
  }
}

module "iam" {
  source = "github.com/moveeeax/terraform-aws-iam"

  name               = "app-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  inline_policies = {
    read-bucket = data.aws_iam_policy_document.read_bucket.json
  }
}
```

Use `inline_policies` for small permissions that only make sense for this
role. Use `policy_documents` when you want the policy visible as its own IAM
object, versioned, or attached later to something else. Values must be valid
JSON; names are checked against IAM's character set and the 128-character
limit at plan time. Both inputs default to `{}`.

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
| `inline_policies`       | Inline policies to embed, policy name => JSON document.        | `map(string)`  | `{}`      |    no    |
| `policy_documents`      | Customer-managed policies to create and attach, key => JSON document. Named `<name>-<key>`. | `map(string)` | `{}` | no |
| `force_detach_policies` | Force-detach attached policies when the role is destroyed.      | `bool`         | `false`   |    no    |
| `tags`                  | Tags applied to the role.                                       | `map(string)`  | `{}`      |    no    |

## Outputs

| Name        | Description                                     |
|-------------|-------------------------------------------------|
| `id`        | Name of the role.                               |
| `arn`       | ARN of the role.                                |
| `name`      | Name of the role.                               |
| `unique_id` | Stable and unique string identifying the role.  |
| `inline_policy_names` | Names of the inline policies embedded in the role. |
| `policy_arns` | ARNs of the customer-managed policies created from `policy_documents`, keyed like the input. |

## License

[MIT](LICENSE)
