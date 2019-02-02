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
 - `public_key_path` the path to the public part of your RSA key (id_rsa.pub). When setting this variable, use forward slashes on Windows or Linux as the path separators
 - `private_key_path` the path to the private part of your RSA key (id_rsa). When setting this variable, use forward slashes on Windows or Linux as the path separators
### Optional configuration
These values may be changed but have defaults already specified
 - `container_image` {default=roottjnii/interview-container:201805} the Docker image to deploy
 - `container_port` {default=4567} the port the container is listening on. The configuration expects this to be a tcp port
 - `instance_count` {default = 1} the number of instances you'd like to run
 - `management_ip_block` {default = 0.0.0.0/0} the ipv4 subnet that has ssh (mangement) access
 - `management_ipv6_block` {default = ::/0} the ipv6 subnet that has ssh (management) access
 - `aws_region` {default = us-east-2} the region you'd like to deploy the infrastructure in
 - `created_by` {default = terraform-nick} a tag assigned to the resources created to separate them from other users or utilities
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

## Management Notes
- Logs can be viewed by ssh-ing into the EC2 instance and checking Docker logs
- Troubleshooting can be done via connecting to the EC2 instance and working with Docker interactively