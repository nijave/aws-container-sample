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
    tags {
        Created-By = "${var.created_by}"
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
    tags {
        AppId = "${var.app_id}"
    }
}
resource "aws_ecs_cluster" "fargate-cluster" {
    name = "fargate-cluster"
    tags {
        Created-By = "${var.created_by}"
    }
}

# Reference https://github.com/turnerlabs/terraform-ecs-fargate/blob/master/env/dev/ecs.tf
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.ecs_task_execution_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_execution_role" {
    name = "ecsTaskExecutionRole"
    assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
    tags {
        Created-By = "${var.created_by}"
    }
}

output "aws_instance_public_dns" {
    value = "${aws_lb.app_alb.dns_name}:80"
}