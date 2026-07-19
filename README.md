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

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| aws       | >= 5.0   |

## Inputs

| Name                   | Description                                                       | Type           | Default   | Required |
|------------------------|-------------------------------------------------------------------|----------------|-----------|:--------:|
| `name`                 | Name of the IAM role.                                            | `string`       | n/a       |   yes    |
| `assume_role_policy`   | JSON trust policy for the role.                                  | `string`       | n/a       |   yes    |
| `description`          | Description of the IAM role.                                     | `string`       | `"Managed by Terraform"` | no |
| `path`                 | Path under which to create the role.                            | `string`       | `"/"`     |    no    |
| `max_session_duration` | Maximum session duration in seconds.                            | `number`       | `3600`    |    no    |
| `managed_policy_arns`  | List of managed policy ARNs to attach.                          | `list(string)` | `[]`      |    no    |
| `tags`                 | Tags applied to the role.                                       | `map(string)`  | `{}`      |    no    |

## Outputs

| Name        | Description                                     |
|-------------|-------------------------------------------------|
| `id`        | Name of the role.                               |
| `arn`       | ARN of the role.                                |
| `name`      | Name of the role.                               |
| `unique_id` | Stable and unique string identifying the role.  |

## License

[MIT](LICENSE)
