resource "aws_ecs_cluster" "fargate-cluster" {
    name = "fargate-cluster"
    tags {
        Created-By = "${var.created_by}"
    }
}

# Reference https://github.com/turnerlabs/terraform-ecs-fargate/blob/master/env/dev/ecs.tf
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.ecs_task_execution_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_execution_role" {
    name = "${format("ecsTaskExecutionRole-%s", local.alphanumeric_app_id)}"
    assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
    tags {
        Created-By = "${var.created_by}"
    }
}