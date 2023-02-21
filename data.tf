data "aws_vpc" "vpc" {
  id = var.vpc_id
}

data "aws_subnets" "application" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }

  tags = {
    subnet-type = "application"
  }
}

data "aws_subnet" "application" {
  for_each = toset(data.aws_subnets.application.ids)
  id       = each.value
}

data "aws_ecs_cluster" "app" {
  cluster_name = local.cluster_name
}

data "aws_service_discovery_dns_namespace" "app" {
  name = local.cluster_name
  type = "DNS_PRIVATE"
}

data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole-${local.cluster_name}"
}

data "aws_lb" "web" {
  name = "${local.cluster_name}-web-lb"
}

data "aws_lb_listener" "https" {
  load_balancer_arn = data.aws_lb.web.arn
  port              = 443
}

data "aws_ecr_repository" "module" {
  name = "${var.name}-${var.module}"
}
