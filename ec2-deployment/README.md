# EC2-Based deployment plan
This plan deploys a single container per EC2 host and exposes these hosts directly to the internet.

## Prerequisites
 - AWS & Terraform listed in the top-level readme file
 - A public/private RSA keypair (for use ssh-ing to the instances)

## Configuration
The deployment has many defaults already set but some values are also required for the deployment. This configuration is provided to Terraform using variables. The usage section contains an example.
### Required configuration (Terraform variables)
 - `aws_access_key` your aws access key
 - `aws_secret_key` your aws secret
 - `public_key_path` the path to the public part of your RSA key (id_rsa.pub)
 - `private_key_path` the path to the private part of your RSA key (id_rsa)
### Optional configuration
These values may be changed but have defaults already specified
 - `container_image` {default=roottjnii/interview-container:201805} the Docker image to deploy
 - `container_port` {default=4567} the port the container is listening on. The configuration expects this to be a tcp port
 - `instance_count` {default = 1} the number of instances you'd like to run
 - `management_ip_block` {default = 0.0.0.0/0} the ipv4 subnet that has ssh (mangement) access
 - `management_ipv6_block` {default = ::/0} the ipv6 subnet that has ssh (management) access
 - `aws_region` {default = us-east-2} the region you'd like to deploy the infrastructure in
 - `created_by` {default = terraform-nick} a tag assigned to the resources created to separate them from other users
 - `app_id` {default = SampleTerraformContainerApp} a tag assigned to all the resources to help identify what app they are for

## Usage
1. Follow pre-requisites in the in the top-level readme (an AWS account & Terraform)