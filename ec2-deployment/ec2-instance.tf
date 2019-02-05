variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "public_key_path" {}
variable "private_key_path" {}
# IP blocks that are allowed to ssh-in

variable "container_image" {default="nijave/flask-test-app"}
variable "container_port" {default=8080}
variable "instance_count" {default=1}
variable "management_ip_block" {default = "0.0.0.0/0"}
variable "management_ipv6_block" {default = "::/0"}
variable "aws_region" {default = "us-east-2"}
variable "created_by" {default = "terraform-nick"}
variable "app_id" {default = "SampleTerraformContainerApp"}

provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"

    region = "${var.aws_region}"
}

resource "aws_key_pair" "infrastructure-deployer" {
    key_name = "instrastructure-developer"
    public_key = "${file(var.public_key_path)}"
}

resource "aws_security_group" "allow_http_ingress" {
  name        = "ec2_http_ingress"
  description = "Allows SSH to EC2 instance from Nicks home IP"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.management_ip_block}"]
    ipv6_cidr_blocks = ["${var.management_ipv6_block}"]
  }
  ingress {
    from_port   = "${var.container_port}"
    to_port     = "${var.container_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags {
        Name = "App EC2 ingress rules"
        Created-By = "${var.created_by}"
        AppId = "${var.app_id}"
    }
}

# This is needed to pull the image from DockerHub
resource "aws_security_group" "allow_public_egress" {
    name = "allow_public_egress"
    description = "Allows egress to any location thats HTTPS"
    egress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
    egress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
    tags {
        Name = "App EC2 egress rules"
        Created-By = "${var.created_by}"
        AppId = "${var.app_id}"
    }
}


# Create an ec2 instance and install nginx
resource "aws_instance" "docker" {
  count = "${var.instance_count}"
  ami = "ami-04328208f4f0cf1fe"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.infrastructure-deployer.key_name}"
  monitoring = true # Required by sandbox
  vpc_security_group_ids = [
      "${aws_security_group.allow_http_ingress.id}",
      "${aws_security_group.allow_public_egress.id}"
      ]
  associate_public_ip_address = true
#   ipv6_address_count = 1

  connection {
    user = "ec2-user"
    host = "${self.public_ip}"
    private_key = "${file(var.private_key_path)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install docker -y",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo docker run -d -p ${var.container_port}:${var.container_port} --restart always --user nobody --name app ${var.container_image}"
    ]
  }
  tags {
        Name = "App EC2 instance"
        Created-By = "${var.created_by}"
        AppId = "${var.app_id}"
    }
}

##################################################################################
# OUTPUT
##################################################################################

output "aws_instance_id" {
    value = "${aws_instance.docker.*.id}"
}
output "aws_instance_public_dns" {
    value = "${aws_instance.docker.*.public_dns}"
}