variable "app_id" {default = "SampleTerraformApp"}
variable "container_image" {default = "roottjnii/interview-container:201805"}
variable "container_port" {default = 4567}
variable "instance_count" {default = 2}
variable "container_cpu" {default = 256}
variable "container_memory" {default = 512}

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