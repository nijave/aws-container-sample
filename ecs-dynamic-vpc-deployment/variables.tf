variable "app_id" {default = "SampleTerraformApp"}

locals {
    # Regex replace non alpha-numeric characters
    alphanumeric_app_id = "${replace(var.app_id, "/[^A-Za-z0-9]/", "-")}"
}