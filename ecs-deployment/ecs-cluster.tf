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

resource "aws_ecs_cluster" "fargate-cluster" {
    name = "fargate-cluster"
}

# Create an ec2 instance and install nginx

##################################################################################
# OUTPUT
##################################################################################

# TODO change to ALB DNS
output "aws_instance_public_dns" {
    value = "${aws_lb.app_alb.dns_name}"
}