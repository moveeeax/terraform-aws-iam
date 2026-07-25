variable "name" {
  description = "Name of the IAM role."
  type        = string
}

variable "assume_role_policy" {
  description = <<-EOT
    JSON trust policy that grants an entity permission to assume the role.

    Two classes of trust policy are rejected outright because they let
    principals the caller never intended assume the role:

      * an `Allow` statement with a wildcard (`*`) principal and no `Condition`,
        which lets any AWS account assume the role;
      * an `Allow` statement whose principal is an OIDC identity provider and
        whose conditions do not pin the `:sub` claim, which lets any identity
        from that provider (e.g. any GitHub repository) assume the role.
  EOT
  type        = string

  validation {
    condition     = can(jsondecode(var.assume_role_policy))
    error_message = "assume_role_policy must be a valid JSON policy document."
  }

  # An Allow statement with a "*" principal is only safe if a Condition narrows
  # who can actually assume the role (e.g. aws:PrincipalOrgID). Statements whose
  # principal cannot be parsed, and documents that are not valid JSON, fall
  # through to `true` here and are reported by the validations around this one.
  validation {
    condition = try(
      alltrue([
        for s in flatten([jsondecode(var.assume_role_policy).Statement]) :
        length([for operator, kv in try(s.Condition, {}) : operator]) > 0
        if try(s.Effect, "Allow") == "Allow" && (
          try(s.Principal == "*", false) ||
          try(anytrue([for pk, pv in s.Principal : contains(flatten([pv]), "*")]), false)
        )
      ]),
      true
    )
    error_message = "assume_role_policy must not Allow a wildcard (\"*\") principal without a Condition that restricts who may assume the role."
  }

  # A web identity trust policy that does not pin the ":sub" claim trusts every
  # identity the provider can issue a token for, not just the intended one.
  validation {
    condition = try(
      alltrue([
        for s in flatten([jsondecode(var.assume_role_policy).Statement]) :
        anytrue([
          for key in flatten([for operator, kv in try(s.Condition, {}) : [for k, v in kv : k]]) :
          endswith(lower(key), ":sub")
        ])
        if try(s.Effect, "Allow") == "Allow" && anytrue([
          for federated in flatten([try(s.Principal.Federated, [])]) :
          can(regex("oidc-provider/", federated))
        ])
      ]),
      true
    )
    error_message = "assume_role_policy must constrain the \":sub\" claim when it Allows an OIDC federated principal, otherwise any identity from that provider can assume the role."
  }
}

variable "description" {
  description = "Description of the IAM role."
  type        = string
  default     = "Managed by Terraform"
}

variable "path" {
  description = "Path under which to create the role."
  type        = string
  default     = "/"
}

variable "permissions_boundary" {
  description = "ARN of the policy used as the permissions boundary for the role. Caps the role's effective permissions regardless of the policies attached to it."
  type        = string
  default     = null
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds for the role."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be between 3600 and 43200 seconds."
  }
}

variable "managed_policy_arns" {
  description = "List of managed policy ARNs to attach to the role."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to the role."
  type        = map(string)
  default     = {}
}
