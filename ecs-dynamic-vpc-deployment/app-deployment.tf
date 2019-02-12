variable "container_image" {default = "nijave/flask-test-app"}
variable "container_port" {default = 8080}
variable "instance_count" {
    description = "Number of container instances. Defaults to 1 per AZ when set to -1"
    default = -1
}
variable "container_cpu" {default = 256}
variable "container_memory" {default = 512}

locals {
    calculated_instance_count = "${var.instance_count == -1 ? local.calculated_az_count : var.instance_count}"
}

resource "aws_security_group" "ecs_ingress_egress" {
  description = "${format("Security group to control container ingress and egress for %s", var.app_id)}"
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
        Name = "${format("%s-sg", local.alphanumeric_app_id)}"
        Created-By = "${var.created_by}"
        AppId = "${var.app_id}"
    }
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

    port = "${var.container_port}"
    protocol = "HTTP"
    target_type = "ip"
    deregistration_delay = 30 # quicker deregistration
    vpc_id = "${aws_vpc.app_vpc.id}"
    # workaround https://github.com/terraform-providers/terraform-provider-aws/issues/636
    lifecycle {
        create_before_destroy = true
    }
    tags {
        Name = "${var.app_id}-group"
        Created-By = "${var.created_by}"
        AppId = "${var.app_id}"
    }
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

resource "aws_cloudwatch_log_group" "container-app-logs" {
    name = "${format("%s-logs", local.alphanumeric_app_id)}"
    retention_in_days = 14
    tags {
        Created-By = "${var.created_by}"
        AppId = "${var.app_id}"
    }
}

resource "aws_ecs_task_definition" "app-task" {
    family = "app-task"
    cpu = "${var.container_cpu}"
    memory = "${var.container_memory}"
    network_mode = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    execution_role_arn = "${aws_iam_role.ecs_task_execution_role.arn}"
    container_definitions = <<DEFINITION
[
    {
        "name": "app",
        "image": "${var.container_image}",
        "essential": true,
        "environment": [
            {"name": "FLASK_PORT", "value": "${var.container_port}"}
        ],
        "portMappings": [
            {
                "containerPort": ${var.container_port},
                "protocol": "tcp"
            }
        ],
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "${aws_cloudwatch_log_group.container-app-logs.name}",
                "awslogs-region": "${var.aws_region}",
                "awslogs-stream-prefix": "ecs"
            }
        }
    }
]
DEFINITION
    tags {
        Created-By = "${var.created_by}"
        AppId = "${var.app_id}"
    }
}

data "aws_ecs_task_definition" "app-task" {
    depends_on = ["aws_ecs_task_definition.app-task"]
    task_definition = "${aws_ecs_task_definition.app-task.family}"
}

resource "aws_ecs_service" "container-app-deployment" {
    name = "${format("%s-service", local.alphanumeric_app_id)}"
    cluster = "${aws_ecs_cluster.fargate-cluster.id}"
    task_definition = "${aws_ecs_task_definition.app-task.id}"
    desired_count = "${local.calculated_instance_count}"
    launch_type = "FARGATE"
    network_configuration {
        assign_public_ip = false
        security_groups = ["${aws_security_group.ecs_ingress_egress.id}"]
        subnets = ["${aws_subnet.private_subnet.*.id}"]
    }
    load_balancer {
        target_group_arn = "${aws_lb_target_group.container-app-target.arn}"
        container_name = "app"
        container_port = "${var.container_port}"
    }
    # Target group must be attached to load balancer before attempting service creation or service creation will fail
    depends_on = ["aws_alb_listener.container-listener", "aws_security_group.ecs_ingress_egress"]
    tags {
        Created-By = "${var.created_by}"
        AppId = "${var.app_id}"
    }
}