locals {
  cluster_name = "${var.environment}-${var.name}"
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

terraform {
  backend "s3" {
    bucket = "terraform-bucket"
    key    = "tfstate.tf"
    region = var.region
  }
}

resource "aws_ecs_task_definition" "module" {
  family                   = "${local.cluster_name}-${var.module}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  task_role_arn            = data.aws_iam_role.ecs_task_execution_role.arn
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([
    {
      name      = "${var.name}-${var.module}"
      image     = "${data.aws_ecr_repository.module.repository_url}:${var.app_version}"
      cpu       = 1
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 1025
          hostPort      = 1025
        },
        {
          containerPort = 1080
          hostPort      = 1080
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "${local.cluster_name}"
          awslogs-region        = "${var.region}"
          awslogs-create-group  = "true"
          awslogs-stream-prefix = "${var.module}"
        }
      }
    }
  ])

}

resource "aws_service_discovery_service" "module" {
  name = var.module

  dns_config {
    namespace_id = data.aws_service_discovery_dns_namespace.app.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_service" "module" {
  name            = "${var.name}-${var.module}"
  cluster         = data.aws_ecs_cluster.app.id
  task_definition = aws_ecs_task_definition.module.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = data.aws_subnets.application.ids
    security_groups  = [aws_security_group.api_module.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.module-lb-target-group.arn
    container_name   = "${var.name}-${var.module}"
    container_port   = 1080
  }
  service_registries {
    registry_arn   = aws_service_discovery_service.module.arn
    container_name = "${var.name}-${var.module}"
  }
}

resource "aws_security_group" "api_module" {
  name   = "${local.cluster_name}-sg-for-${var.module}"
  vpc_id = data.aws_vpc.vpc.id

  ingress {
    protocol    = "tcp"
    self        = true
    from_port   = 1080
    to_port     = 1080
    cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  }

  ingress {
    protocol    = "tcp"
    self        = true
    from_port   = 1025
    to_port     = 1025
    cidr_blocks = [for s in data.aws_subnet.application : s.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_lb_target_group" "module-lb-target-group" {
  name                 = "${local.cluster_name}-${var.module}-lb-tg"
  port                 = 1080
  protocol             = "HTTP"
  target_type          = "ip"
  deregistration_delay = 30
  vpc_id               = data.aws_vpc.vpc.id
  health_check {
    enabled             = true
    path                = "/api/emails"
    port                = 1080
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-499"
    interval            = 300
  }
}

resource "aws_lb_listener_rule" "module" {
  listener_arn = data.aws_lb_listener.https.arn
  priority     = 150

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.module-lb-target-group.arn
  }

  condition {
    path_pattern {
      values = ["/api/emails*"]
    }
  }

}
