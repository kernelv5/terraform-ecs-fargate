resource "aws_ecs_cluster" "ecs-cluster" {
  name = "${var.project_name}-ecs-${terraform.workspace}"
  tags = var.tags_value
}

# Pre-requisite
resource "aws_ecr_repository" "erc" {
  name                 = "${var.name_context}-erc"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
/*
Create IAM rules for Container Execution Permission
https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html
*/
data "aws_iam_policy_document" "ecs_tasks_execution_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "ecs_tasks_execution_role" {
  name               = "${var.name_context}-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_execution_role.json

  tags = var.tags_value
}
resource "aws_iam_role_policy_attachment" "ecs_tasks_execution_role" {
  role       = aws_iam_role.ecs_tasks_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_cloudwatch_log_group" "cloudwatch" {
  name = "/ecs/${var.project_name}/${terraform.workspace}"

  tags = var.tags_value
}

resource "aws_ecs_task_definition" "app_task_definition" {
  family = "${var.name_context}-task_definition"

  task_role_arn = aws_iam_role.ecs_tasks_execution_role.arn
  execution_role_arn = aws_iam_role.ecs_tasks_execution_role.arn

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048

  container_definitions = templatefile("${path.module}/task-01.json.tftpl",{
    app_name          = "${var.name_context}-app",
    app_memory        = var.app_memory,
    container_port    = var.container_port,
    app_cpu           = var.app_cpu,
    host_port         = var.container_port,
    image_url         = aws_ecr_repository.erc.repository_url,
    image_tag         = var.image_tag,
    log_group         = aws_cloudwatch_log_group.cloudwatch.name
    awslogs-region    = var.awslogs-region
    awslogs-stream-prefix = var.awslogs-stream-prefix

  })
}

resource "aws_ecs_service" "app_service" {
  name            = "${var.name_context}-task_definition"
  cluster         = aws_ecs_cluster.ecs-cluster.id
  task_definition = aws_ecs_task_definition.app_task_definition.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  platform_version = var.platform_version

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "${var.name_context}-app"
    container_port   = var.container_port
  }

  network_configuration {
    subnets          =  var.subnet
    security_groups  =  [ var.container_security_groups ]
    assign_public_ip = true
  }
}