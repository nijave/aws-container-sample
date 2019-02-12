# AWS Terraform Example

This repository provides two different sample deployments
  1. EC2 instance based using the Docker daemon
  2. ECS based with a load balancer in front

## Pre-requisites
 1. An AWS account with an access token and secret (or other credentials that work with terraform)
 2. Terraform [download](https://www.terraform.io/downloads.html)

## 1. EC2 Based (`ec2-deployment/`)
This deployment plan creates VMs and exposes the containers directly. This configuration uses 1 VM per container instance and is configured to automatically restart crashed containers. This deployment is suitable for a development environment. Additional details can be found in the `ec2-deployment/` directory

## 2. ECS based deployment (`ecs-deployment/`)
This deployment utilizes the Amazon Elastic Container Service (ECS). ECS handles container lifecycle and cleanly integrates with the Application Load Balancer (ALB) to provide high-availability. This deployment is suitable for a production environment. More details can be found in the `ecs-deployment/` directory

## Multiple environments
The recommended approach to multiple environments is using the same configuration base against serparate AWS accounts. Terraform stores state in the folder, so the folder will need to be copied per environment.