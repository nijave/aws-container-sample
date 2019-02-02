variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "container_image" {default = "roottjnii/interview-container:201805"}
variable "container_port" {default = 4567}
variable "instance_count" {default = 2}
variable "container_cpu" {default = 256}
variable "container_memory" {default = 512}
variable "aws_region" {default = "us-east-2"}
variable "app_id" {default = "SampleTerraformApp"}

provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.aws_region}"
}

# Create a new network to segregate resources
resource "aws_vpc" "app_vpc" {
    enable_dns_support = true
    enable_dns_hostnames = true
    cidr_block = "10.0.0.0/16"
    assign_generated_ipv6_cidr_block = true
    tags {
        Name = "App VPC"
        Created-By = "terraform-nick"
        AppId = "${var.app_id}"
    }
}

# Give the network internet access
resource "aws_internet_gateway" "public_gw" {
    vpc_id = "${aws_vpc.app_vpc.id}"
    tags {
        Name = "App VPC IG"
        Created-By = "terraform-nick"
        AppId = "${var.app_id}"
    }
}

# Add a route through the IG to the internet
resource "aws_default_route_table" "app_vpc_route_table" {
    default_route_table_id = "${aws_vpc.app_vpc.default_route_table_id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_nat_gateway.nat_gw.id}"
    }
    route {
        ipv6_cidr_block = "::/0"
        gateway_id = "${aws_internet_gateway.public_gw.id}"
    }
    tags {
        Name = "App VPC default route table"
        Created-By = "terraform-nick"
        AppId = "${var.app_id}"
    }
}

# Create a new subnet in the network for the application to run (the subnet will get internet acces)
resource "aws_subnet" "public_subnet" {
    vpc_id = "${aws_vpc.app_vpc.id}"
    cidr_block = "${cidrsubnet(aws_vpc.app_vpc.cidr_block, 8, 254)}"
    ipv6_cidr_block = "${cidrsubnet(aws_vpc.app_vpc.ipv6_cidr_block, 8, 254)}"
    tags {
        Name = "App VPC Public Subnet"
        Created-By = "terraform-nick"
        AppId = "${var.app_id}"
    }
}

resource "aws_route_table" "public-route-table" {
    vpc_id = "${aws_vpc.app_vpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.public_gw.id}"
    }
    route {
        ipv6_cidr_block = "::/0"
        gateway_id = "${aws_internet_gateway.public_gw.id}"
    }
}

resource "aws_route_table_association" "public-route-table-to-subnet" {
    subnet_id = "${aws_subnet.public_subnet.id}"
    route_table_id = "${aws_route_table.public-route-table.id}"
}

resource "aws_eip" "nat_ip" {
    vpc = true
}

resource "aws_nat_gateway" "nat_gw" {
    allocation_id = "${aws_eip.nat_ip.id}"
    subnet_id = "${aws_subnet.public_subnet.id}"
    depends_on = ["aws_internet_gateway.public_gw"]
}

resource "aws_subnet" "private_subnet1" {
    vpc_id = "${aws_vpc.app_vpc.id}"
    cidr_block = "${cidrsubnet(aws_vpc.app_vpc.cidr_block, 8, 0)}"
    ipv6_cidr_block = "${cidrsubnet(aws_vpc.app_vpc.ipv6_cidr_block, 8, 0)}"
    availability_zone = "${var.aws_region}a"
    tags {
        Name = "App VPC Private Subnet"
        Created-By = "terraform-nick"
        AppId = "${var.app_id}"
    }
}

resource "aws_subnet" "private_subnet2" {
    vpc_id = "${aws_vpc.app_vpc.id}"
    cidr_block = "${cidrsubnet(aws_vpc.app_vpc.cidr_block, 8, 1)}"
    ipv6_cidr_block = "${cidrsubnet(aws_vpc.app_vpc.ipv6_cidr_block, 8, 1)}"
    availability_zone = "${var.aws_region}b"
    tags {
        Name = "App VPC Private Subnet"
        Created-By = "terraform-nick"
        AppId = "${var.app_id}"
    }
}

resource "aws_security_group" "alb_public_ingress" {
    name = "alb_public_ingress"
    description = "Allows ingress from the internet to the alb and communication with ECS containers"
    vpc_id = "${aws_vpc.app_vpc.id}"
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
    # ALB can talk to any private instances
    egress {
        from_port = 0
        to_port = 65535
        protocol = "tcp"
        cidr_blocks = ["${aws_subnet.private_subnet1.cidr_block}", "${aws_subnet.private_subnet2.cidr_block}"]
        ipv6_cidr_blocks = ["${aws_subnet.private_subnet1.ipv6_cidr_block}", "${aws_subnet.private_subnet2.ipv6_cidr_block}"]
    }
}

resource "aws_security_group" "ecs_ingress_egress" {
  name        = "ecs_ingress_egress"
  description = "Security group to control container ingress and egress"
  vpc_id = "${aws_vpc.app_vpc.id}"
  # Allow ALB in
  ingress {
      from_port = "${var.container_port}"
      to_port = "${var.container_port}"
      protocol = "tcp"
      security_groups = ["${aws_security_group.alb_public_ingress.id}"]
  }
  # HTTP out to pull container from DockerHub
  # DockerHub uses ELB so IP whitelist would be difficult here
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
        Created-By = "terraform-nick"
        AppId = "${var.app_id}"
    }
}

# Create ALB
resource "aws_lb" "app_alb" {
    name = "container-app-alb"
    internal = false
    security_groups = [
        "${aws_security_group.alb_public_ingress.id}"
    ]
    subnets = [
        "${aws_subnet.private_subnet1.id}",
        "${aws_subnet.private_subnet2.id}"
    ]
    ip_address_type = "dualstack"
    load_balancer_type = "application"
}

# Target group for load balancer
resource "aws_lb_target_group" "container-app-target" {
    health_check {
        interval = 15
        path = "/"
        protocol = "HTTP"
        timeout = 5
        healthy_threshold = 3
        unhealthy_threshold = 2
        matcher = "200"
    }

    name = "container-app-group"
    port = "${var.container_port}"
    protocol = "HTTP"
    target_type = "ip"
    deregistration_delay = 30 # quicker deregistration
    vpc_id = "${aws_vpc.app_vpc.id}"
}

resource "aws_alb_listener" "container-listener" {
    load_balancer_arn = "${aws_lb.app_alb.arn}"
    port = 80
    protocol = "HTTP"
    default_action {
        target_group_arn = "${aws_lb_target_group.container-app-target.arn}"
        type = "forward"
    }
}

resource "aws_ecs_cluster" "fargate-cluster" {
    name = "fargate-cluster"
}

resource "aws_ecs_task_definition" "app-task" {
    family = "app-task"
    cpu = "${var.container_cpu}"
    memory = "${var.container_memory}"
    network_mode = "awsvpc"
    container_definitions = <<DEFINITION
[
    {
        "name": "app",
        "image": "${var.container_image}",
        "essential": true,
        "portMappings": [
            {
                "containerPort": ${var.container_port},
                "protocol": "tcp"
            }
        ]
    }
]
DEFINITION
}

data "aws_ecs_task_definition" "app-task" {
    depends_on = ["aws_ecs_task_definition.app-task"]
    task_definition = "${aws_ecs_task_definition.app-task.family}"
}

resource "aws_ecs_service" "container-app-deployment" {
    name = "ruby-app-service"
    cluster = "${aws_ecs_cluster.fargate-cluster.id}"
    task_definition = "${aws_ecs_task_definition.app-task.id}"
    desired_count = "${var.instance_count}"
    launch_type = "FARGATE"
    network_configuration {
        assign_public_ip = false
        security_groups = ["${aws_security_group.ecs_ingress_egress.id}"]
        subnets = ["${aws_subnet.private_subnet1.id}", "${aws_subnet.private_subnet2.id}"]
    }
    load_balancer {
        target_group_arn = "${aws_lb_target_group.container-app-target.arn}"
        container_name = "app"
        container_port = "${var.container_port}"
    }
}
# Create an ec2 instance and install nginx

##################################################################################
# OUTPUT
##################################################################################

# TODO change to ALB DNS
output "aws_instance_public_dns" {
    value = "${aws_lb.app_alb.dns_name}"
}