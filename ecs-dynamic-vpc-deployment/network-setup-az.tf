# ascii text http://patorjk.com/software/taag/#p=display&f=Standard
#  __     ______   ____   ____       _               
#  \ \   / /  _ \ / ___| / ___|  ___| |_ _   _ _ __  
#   \ \ / /| |_) | |     \___ \ / _ \ __| | | | '_ \ 
#    \ V / |  __/| |___   ___) |  __/ |_| |_| | |_) |
#     \_/  |_|    \____| |____/ \___|\__|\__,_| .__/ 
#                                             |_|    
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

#   ___       _                       _      ____       _                             ____       _               
#  |_ _|_ __ | |_ ___ _ __ _ __   ___| |_   / ___| __ _| |_ _____      ____ _ _   _  / ___|  ___| |_ _   _ _ __  
#   | || '_ \| __/ _ \ '__| '_ \ / _ \ __| | |  _ / _` | __/ _ \ \ /\ / / _` | | | | \___ \ / _ \ __| | | | '_ \ 
#   | || | | | ||  __/ |  | | | |  __/ |_  | |_| | (_| | ||  __/\ V  V / (_| | |_| |  ___) |  __/ |_| |_| | |_) |
#  |___|_| |_|\__\___|_|  |_| |_|\___|\__|  \____|\__,_|\__\___| \_/\_/ \__,_|\__, | |____/ \___|\__|\__,_| .__/ 
#                                                                             |___/                       |_|    
resource "aws_internet_gateway" "public_gw" {
    vpc_id = "${aws_vpc.app_vpc.id}"
    tags {
        Name = "App VPC IG"
        Created-By = "${var.created_by}"
    }
}

# IPv6 doesn't use NAT so create an egress only gateway to prevent incoming connections
# See https://aws.amazon.com/premiumsupport/knowledge-center/configure-private-ipv6-subnet/
resource "aws_egress_only_internet_gateway" "egress_gw" {
    vpc_id = "${aws_vpc.app_vpc.id}"
    # This resource doesn't support tags
}

resource "aws_eip" "nat_ip" {
    vpc = true
    count = "${local.calculated_az_count}"
    tags {
        Created-By = "${var.created_by}"
    }
}

resource "aws_nat_gateway" "nat_gw" {
    allocation_id = "${element(aws_eip.nat_ip.*.id, count.index)}"
    subnet_id = "${element(aws_subnet.public_subnet.*.id, count.index)}"
    depends_on = ["aws_internet_gateway.public_gw"]
    tags {
        Created-By = "${var.created_by}"
    }
}

#   ____        _                _     ____       _               
#  / ___| _   _| |__  _ __   ___| |_  / ___|  ___| |_ _   _ _ __  
#  \___ \| | | | '_ \| '_ \ / _ \ __| \___ \ / _ \ __| | | | '_ \ 
#   ___) | |_| | |_) | | | |  __/ |_   ___) |  __/ |_| |_| | |_) |
#  |____/ \__,_|_.__/|_| |_|\___|\__| |____/ \___|\__|\__,_| .__/ 
#                                                          |_|    
resource "aws_subnet" "private_subnet" {
    vpc_id = "${aws_vpc.app_vpc.id}"
    count = "${local.calculated_az_count}"
    cidr_block = "${cidrsubnet(cidrsubnet(aws_vpc.app_vpc.cidr_block, 1, 0), 7, count.index)}"
    ipv6_cidr_block = "${cidrsubnet(cidrsubnet(aws_vpc.app_vpc.ipv6_cidr_block, 1, 0), 7, count.index)}"
    availability_zone = "${format("%s%s", var.aws_region, element(var.azs, count.index))}"
    tags {
        Name = "${format("App VPC Private Subnet %d", count.index)}"
        Created-By = "${var.created_by}"
    }
}

resource "aws_route_table" "private_route_table" {
    vpc_id = "${aws_vpc.app_vpc.id}"
    count = "${local.calculated_az_count}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${element(aws_nat_gateway.nat_gw.*.id, count.index)}"
    }
    route {
        ipv6_cidr_block = "::/0"
        gateway_id = "${aws_egress_only_internet_gateway.egress_gw.id}"
    }
    tags {
        Name = "${format("Private route table for %d", count.index)}"
        Created-By = "${var.created_by}"
    }
}

resource "aws_route_table_association" "private_route_table_association" {
    count = "${local.calculated_az_count}"
    subnet_id = "${element(aws_subnet.private_subnet.*.id, count.index)}"
    route_table_id = "${element(aws_route_table.private_route_table.*.id, count.index)}"
}

resource "aws_subnet" "public_subnet" {
    vpc_id = "${aws_vpc.app_vpc.id}"
    count = "${local.calculated_az_count}"
    cidr_block = "${cidrsubnet(cidrsubnet(aws_vpc.app_vpc.cidr_block, 1, 1), 7, count.index)}"
    ipv6_cidr_block = "${cidrsubnet(cidrsubnet(aws_vpc.app_vpc.ipv6_cidr_block, 1, 1), 7, count.index)}"
    availability_zone = "${format("%s%s", var.aws_region, element(var.azs, count.index))}"
    tags {
        Name = "${format("App VPC Public Subnet %d", count.index)}"
        Created-By = "${var.created_by}"
    }
}


resource "aws_route_table" "public_route_table" {
    vpc_id = "${aws_vpc.app_vpc.id}"
    count = "${local.calculated_az_count}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.public_gw.id}"
    }
    route {
        ipv6_cidr_block = "::/0"
        gateway_id = "${aws_internet_gateway.public_gw.id}"
    }
    tags {
        Name = "${format("Public route table for %d", count.index)}"
        Created-By = "${var.created_by}"
    }
}

resource "aws_route_table_association" "public_route_table_association" {
    count = "${local.calculated_az_count}"
    subnet_id = "${element(aws_subnet.public_subnet.*.id, count.index)}"
    route_table_id = "${element(aws_route_table.public_route_table.*.id, count.index)}"
}