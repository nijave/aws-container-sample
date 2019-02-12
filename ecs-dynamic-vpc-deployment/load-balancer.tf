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
        cidr_blocks = ["${aws_subnet.private_subnet.*.cidr_block}"]
        ipv6_cidr_blocks = ["${aws_subnet.private_subnet.*.ipv6_cidr_block}"]
    }
    tags {
        Created-By = "${var.created_by}"
    }
}
resource "aws_lb" "app_alb" {
    name = "${format("%s-ALB", local.alphanumeric_app_id)}"
    internal = false
    security_groups = [
        "${aws_security_group.alb_public_ingress.id}"
    ]
    subnets = ["${aws_subnet.public_subnet.*.id}"]
    ip_address_type = "dualstack"
    load_balancer_type = "application"
    tags {
        AppId = "${var.app_id}"
    }
}

output "aws_instance_public_dns" {
    value = "${aws_lb.app_alb.dns_name}:80"
}