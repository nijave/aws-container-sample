variable "created_by" {default = "terraform-nick"}
variable "aws_region" {default = "us-east-2"}
variable "azs" {
    description = "List of availability zones in a region to deploy to"
    type = "list"
    default = ["a", "b", "c"]
}

variable "az_count" {
    description = "Number of availability zones to deploy in. Defaults to all of them when set to -1"
    default = -1
}

variable "app_id" {default = "SampleTerraformApp"}
locals {
    calculated_az_count = "${var.az_count == -1 ? length(var.azs) : var.az_count}"
    # Regex replace non alpha-numeric characters
    alphanumeric_app_id = "${replace(var.app_id, "/[^A-Za-z0-9]/", "-")}"
}