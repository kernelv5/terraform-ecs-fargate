locals {

  project_name  =  "picante"
  name_context    = "${local.project_name}-${terraform.workspace}"

  dynamic_tag   = {
    Environment   =  terraform.workspace
    Project = local.project_name
  }

  tags  = merge(var.global_tag,var.project_tag,local.dynamic_tag)

  vpc_id              = "vpc-02e45c4d117260462"
  subnet              = [ "subnet-04792df347f8f26c4" , "subnet-0bfb2951eba202c6b" , "subnet-03cc51513b5cc63ae"]
  subnet_public       = [ "subnet-05da5e1b6c3fcace5" , "subnet-03225a15983db3143" , "subnet-0fa25fd6b69366a30"]
  route_table_private = ["rtb-0ce98ddd688ab806f"]

  container_port  = "80"
  awslogs-region  = var.region
  awslogs-stream-prefix = "ecs"

}

module "sg-alb-public" {
  source = "terraform-aws-modules/security-group/aws"
  name        = "${local.name_context}-sg-alb-public"
  description = "Public Traffic"
  vpc_id      = local.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp"]

}
module "sg-container" {
  depends_on = [module.sg-alb-public]
  source = "terraform-aws-modules/security-group/aws"
  name        = "${local.name_context}-sg-container"
  description = "ECS Container "
  vpc_id      = local.vpc_id

  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["http-80-tcp","https-443-tcp"]
  ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.sg-alb-public.security_group_id
    }
  ]
}
module "alb-to-container" {
  source = "terraform-aws-modules/security-group/aws"

  create_sg         = false
  security_group_id = module.sg-alb-public.security_group_id
  egress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.sg-container.security_group_id
    }
    ]
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.8"
  name = "${local.name_context}-alb"
  load_balancer_type = "application"
  internal = false
  drop_invalid_header_fields  = true

  target_groups = [
    {
      name_prefix      = "HTTP"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "ip"
      targets = []
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/"
        port                = "80"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200-410"
      }
    }
  ]

  vpc_id             = local.vpc_id
  subnets            = local.subnet_public
  security_groups    = [module.sg-alb-public.security_group_id]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      action_type = "fixed-response"
      fixed_response = {
        content_type = "text/plain"
        message_body = "Access Denied"
        status_code  = "403"
      }
    }
  ]

  http_tcp_listener_rules = [
    {
      http_tcp_listener_index = 0
      priority                = 1
      actions = [{
        type         = "forward"
        target_group_arn = module.alb.lb_arn
      }]

      conditions = [{
        http_headers = [{
          http_header_name = "X-Forwarded-Scheme"
          values           = ["https"]
        }]
      },
      ]
    }
  ]
}
module "ecs-cluster" {
  source = "./module/ecs-cluster"
  container_port = local.container_port
  app_memory  = 2048
  app_cpu = 1024

  #https://docs.aws.amazon.com/AmazonECS/latest/developerguide/platform-linux-fargate.html
  platform_version  = "1.4.0"
  tags_value = local.tags
  image_tag = "latest"
  name_context  = local.name_context
  project_name = local.project_name
  target_group_arn =  "${element(module.alb.target_group_arns ,0)}"
  container_security_groups = module.sg-container.security_group_id
  subnet = local.subnet
  awslogs-region  = var.region
  awslogs-stream-prefix = local.awslogs-stream-prefix
}
module "cdn" {
  source = "terraform-aws-modules/cloudfront/aws"
  version = "2.9.3"

  #aliases = ["cdn.example.com"]

  comment             = "Managed by Terraform"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = false

  origin = {
    something = {
      domain_name = module.alb.lb_dns_name
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "http-only"
        origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
      },
      custom_header = [
        {
          name  = "X-Forwarded-Scheme"
          value = "https"
        },
        {
          name  = "X-Frame-Options"
          value = "SAMEORIGIN"
        }
      ]
    }}

  default_cache_behavior = {
    target_origin_id           = "something"
    viewer_protocol_policy     = "allow-all"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true
    query_string    = true
  }
}

output "cdn_domain" {
  value = module.cdn.cloudfront_distribution_domain_name
}