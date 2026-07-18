variable "name" {
  description = "Name of the IAM role."
  type        = string
}

variable "assume_role_policy" {
  description = "JSON trust policy that grants an entity permission to assume the role."
  type        = string
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
