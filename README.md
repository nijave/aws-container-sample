# root-insurance-interview

This repository provides two different sample deployments
  1. EC2 instance based using the Docker daemon
  2. ECS based with a load balancer in front

## 1. EC2 Based
This deployment plan creates VMs and exposes the containers directly. This configuration uses 1 VM per container instance and is configured to automatically restart crashed containers. This deployment is suitable for a development environment. Additional details can be found in the ec2-deployment/ directory