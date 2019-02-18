variable "created_by" {default = "terraform-nick"}
variable "aws_region" {default = "us-east-2"}

provider "aws" {
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
        Created-By = "${var.created_by}"
    }
}

# Give the network internet access
resource "aws_internet_gateway" "public_gw" {
    vpc_id = "${aws_vpc.app_vpc.id}"
    tags {
        Name = "App VPC IG"
        Created-By = "${var.created_by}"
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
        Created-By = "${var.created_by}"
    }
}

# Create a new subnet in the network for the application to run (the subnet will get internet acces)
resource "aws_subnet" "public_subnet" {
    vpc_id = "${aws_vpc.app_vpc.id}"
    cidr_block = "${cidrsubnet(aws_vpc.app_vpc.cidr_block, 8, 254)}"
    ipv6_cidr_block = "${cidrsubnet(aws_vpc.app_vpc.ipv6_cidr_block, 8, 254)}"
    tags {
        Name = "App VPC Public Subnet"
        Created-By = "${var.created_by}"
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
    tags {
        Created-By = "${var.created_by}"
    }
}

resource "aws_route_table_association" "public-route-table-to-subnet" {
    subnet_id = "${aws_subnet.public_subnet.id}"
    route_table_id = "${aws_route_table.public-route-table.id}"
}

resource "aws_eip" "nat_ip" {
    vpc = true
    tags {
        Created-By = "${var.created_by}"
    }
}

resource "aws_nat_gateway" "nat_gw" {
    allocation_id = "${aws_eip.nat_ip.id}"
    subnet_id = "${aws_subnet.public_subnet.id}"
    depends_on = ["aws_internet_gateway.public_gw"]
    tags {
        Created-By = "${var.created_by}"
    }
}

resource "aws_subnet" "private_subnet1" {
    vpc_id = "${aws_vpc.app_vpc.id}"
    cidr_block = "${cidrsubnet(aws_vpc.app_vpc.cidr_block, 8, 0)}"
    ipv6_cidr_block = "${cidrsubnet(aws_vpc.app_vpc.ipv6_cidr_block, 8, 0)}"
    availability_zone = "${var.aws_region}a"
    tags {
        Name = "App VPC Private Subnet"
        Created-By = "${var.created_by}"
    }
}

resource "aws_subnet" "private_subnet2" {
    vpc_id = "${aws_vpc.app_vpc.id}"
    cidr_block = "${cidrsubnet(aws_vpc.app_vpc.cidr_block, 8, 1)}"
    ipv6_cidr_block = "${cidrsubnet(aws_vpc.app_vpc.ipv6_cidr_block, 8, 1)}"
    availability_zone = "${var.aws_region}b"
    tags {
        Name = "App VPC Private Subnet"
        Created-By = "${var.created_by}"
    }
}