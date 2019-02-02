# ECS-Based deployment plan
This plan deploys two containers on AWS Elastic Container Service (ECS) and places a load balancer in front to route traffic to both instances. The load balancer employs a healthcheck which will recycle containers if an HTTP check fails. In addition, ECS will automatically restart crashed containers. This plan is more suitable for a production environment requiring high availability. Additionally, this plan eases management by removing the need to manage the operating system configuration when using an EC2 instance. Finally, AWS will allow you to graceful deploy new versions using this pattern which can be slowly cycled and added to the load balancer remove the old version is removed.

## Prerequisites
 - AWS & Terraform listed in the top-level readme file

## Configuration
The deployment has many defaults already set but some values are also required for the deployment. This configuration is provided to Terraform using variables. The usage section contains an example.
### Required configuration (Terraform variables)
 - `aws_access_key` your aws access key
 - `aws_secret_key` your aws secret
### Optional configuration
These values may be changed but have defaults already specified
 - `container_image` {default=roottjnii/interview-container:201805} the Docker image to deploy
 - `container_port` {default=4567} the port the container is listening on. The configuration expects this to be a tcp port
 - `instance_count` {default = 2} the number of instances you'd like to run
 - `aws_region` {default = us-east-2} the region you'd like to deploy the infrastructure in
 - `created_by` {default = terraform-nick} a tag assigned to the resources created to separate them from other users
 - `app_id` {default = SampleTerraformContainerApp} a tag assigned to all the resources to help identify what app they are for

## Usage
1. Follow pre-requisites in the in the top-level readme (an AWS account & Terraform)
2. Create your configuration file. You may specific these with the Terraform command or via a tfvars file.
Inline: `<terraform command> -var="aws_access_key=1234" -var="aws_secret_key=1234"`  
In a var file: `<terraform command> -var-file="myvars.tfvars"`  
The vars file looks like this
    ```
    aws_access_key = "1234"
    aws_secret_key = "1234"
    public_key_path = "C:/Users/me/.ssh/id_rsa.pub"
    ```
3. Once you have the necessary configuration ready, initialize Terraform by opening a command prompt to this directory and executing  
`terraform init`
4. Next, check Terraform's calculated plan for creating the infrastructure (or specify the variables inline)  
`terraform plan -var-file="myvars.tfvars" -out="infrastructure-plan"`
5. Review the Terraform plan
6. Apply the Terraform plan. Terraform will attempt to create the requested resources (which will incur costs on AWS). Terraform may ask for confirmation during this step  
`terraform apply "infrastructure-plan"`
7. Review created resources on AWS. Terraform will output AWS generated DNS names for the provided infrastructure.
8. (optional) Run `terraform destroy` to remove provisioned infrastructure.

Note: Terraform will generate additional files it uses to track the state of the infrastructure on AWS. Additional information on managing these files can be found in [Terraform documentation](https://www.terraform.io/docs/state/index.html)

## Description of infrastructure created
- Network
  - VPC
  - 2 private subnets (in different availability zones)
  - 1 public subnet
  - 1 internet gateway
  - 1 nat gateway (needed to pull image from DockerHub without containers having public IPs)
  - 1 elastic ip for nat gateway
  - 1 routing table for internet access through nat gateway
  - 1 application load balancer
  - __1 target group to load balance containers__
- Compute
  - 1 ecs cluster
  - __1 container task definition__
  - __1 container (ecs/fargate) service with 2 task instances (containers)__

** Items in bold are application specific--the rest of the infrastructure may be re-used for another applications.
** Note: Zero down upgrade can be achieved by changing the Docker image and rerunning Terraform. This won't work if the port changes.