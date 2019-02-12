provider "aws" {
    # access_key = "${var.aws_access_key}"
    # secret_key = "${var.aws_secret_key}"
    shared_credentials_file = "C:/Users/Nick/.aws/credentials"
    profile = "adfs"
    region = "${var.aws_region}"
}