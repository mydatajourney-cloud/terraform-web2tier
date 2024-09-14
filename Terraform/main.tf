provider "aws"{
  region = "ap-southeast-1"
}

#rds
resource "aws_security_group" "rds-sg" {
  name        = "rds-security-group"
  description = "the rds sg"
  vpc_id      = aws_vpc.web_2_tier.id

  ingress {
    description      = "mysql"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}

resource "aws_db_subnet_group" "rds-subnet-group" {
  name       = "rds-subnet-group"
  subnet_ids = [
    aws_subnet.private_subnets[2].id,
    aws_subnet.private_subnets[3].id
  ]

  tags = {
    Name = "My DB subnet group"
  }
}
resource "aws_db_instance" "mysql-rds" {
  db_name              = "db_web_2_tier"
  engine               = "mysql"
  engine_version       = "8.0.35"
  instance_class       = "db.t3.micro"
  username             = "admin"
  password             = "yourpass"
  skip_final_snapshot  = true
  backup_retention_period = 7
  vpc_security_group_ids = [aws_security_group.rds-sg.id]
  multi_az                = true
  storage_type            = "gp2"
  allocated_storage    = 20
  db_subnet_group_name = aws_db_subnet_group.rds-subnet-group.name
}

# VPC
resource "aws_vpc" "web_2_tier" {
 cidr_block = "10.0.0.0/16"
 
 tags = {
   Name = "Project VPC"
 }
}
 
resource "aws_subnet" "public_subnets" {
 count      = length(var.public_subnet_cidrs)
 vpc_id     = aws_vpc.web_2_tier.id
 cidr_block = element(var.public_subnet_cidrs, count.index)
 availability_zone = element(var.azs, count.index)
 tags = {
   Name = "Public Subnet ${count.index + 1}"
 }
}

resource "aws_subnet" "private_subnets" {
 count      = length(var.private_subnet_cidrs)
 vpc_id     = aws_vpc.web_2_tier.id
 cidr_block = element(var.private_subnet_cidrs, count.index)
 availability_zone = element(var.azs, count.index)
 
 tags = {
   Name = "Private Subnet ${count.index + 1}"
 }
}

resource "aws_internet_gateway" "gw" {
 vpc_id = aws_vpc.web_2_tier.id
 
 tags = {
   Name = "Project VPC IG"
 }
}

resource "aws_route_table" "second_rt" {
 vpc_id = aws_vpc.web_2_tier.id
 
 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.gw.id
 }
 
 tags = {
   Name = "2nd Route Table"
 }
}

resource "aws_route_table_association" "public_subnet_asso" {
 count = length(var.public_subnet_cidrs)
 subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
 route_table_id = aws_route_table.second_rt.id
}

resource "aws_eip" "nat_eip" {
  vpc      = true
  tags = {
    "Name" = "CustomEIP"
  }
}
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id

  subnet_id     = aws_subnet.public_subnets[0].id
  depends_on    = [aws_internet_gateway.gw]
}
resource "aws_route_table" "nat_route_table" {
  vpc_id = aws_vpc.web_2_tier.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "nat_route_table_asso" {
  count = length(var.private_subnet_cidrs)
  subnet_id = element(aws_subnet.private_subnets[*].id, count.index)
  route_table_id = aws_route_table.nat_route_table.id
}

# alb
resource "aws_security_group" "alb-sg" {
  name        = "alb-security-group"
  description = "the alb sg"
  vpc_id      = aws_vpc.web_2_tier.id

  ingress {
    description      = "Allow HTTP traffic from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS traffic from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# target group
resource "aws_lb_target_group" "target-group" {
  name        = "nit-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.web_2_tier.id
  ip_address_type    = "ipv4"


  health_check {
    enabled             = true
    interval            = 10
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

}

resource "aws_lb_listener" "alb-listener" {
  load_balancer_arn = aws_lb.alb_test.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target-group.arn
  }
}


resource "aws_lb" "alb_test" {
  name               = "alb-test"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-sg.id]
  subnets            = [for subnet in aws_subnet.public_subnets : subnet.id]

  enable_deletion_protection = true



  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group_attachment" "tg_attachment" {
  count            = 2
  target_group_arn = aws_lb_target_group.target-group.arn
  target_id        = aws_instance.webserver-ec2.id
  port             = 80
}


# Launch Template for ASG
resource "aws_launch_template" "app" {
  name_prefix = "app-template"
  image_id = var.ami_id
  instance_type = "t2.micro"
  key_name = "mykeypair"
  user_data = base64encode(<<-EOF
    #!/bin/bash
    RDS_ENDPOINT="${aws_db_instance.mysql-rds.endpoint}"
    cat <<EOL > /var/www/inc/dbinfo.inc
    <?php
    define('DB_SERVER','${aws_db_instance.mysql-rds.endpoint}');
    define('DB_USERNAME', 'admin');
    define('DB_PASSWORD', 'Lolaboba123$');
    define('DB_DATABASE', 'db_web_2_tier');
    ?>
    sudo systemctl restart httpd
    EOL
  EOF
  )
  network_interfaces {
    associate_public_ip_address = false
    security_groups = [aws_security_group.ec2-security-group.id]
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app_asg" {
  desired_capacity     = 2
  max_size             = 3
  min_size             = 1
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
  vpc_zone_identifier = [for subnet in aws_subnet.private_subnets : subnet.id]
  target_group_arns = [aws_lb_target_group.target-group.arn]

  tag {
    key                 = "Name"
    value               = "app-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}
