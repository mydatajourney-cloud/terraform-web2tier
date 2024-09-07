
resource "aws_security_group" "ec2-security-group" {
  name        = "ec2-security-group"
  description = "ec2 sg"
  vpc_id      = aws_vpc.web_2_tier.id

  ingress {
    description      = "Allow HTTP traffic from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH traffic from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
    Name = "ec2-sg"
  }
}
resource "aws_instance" "webserver-ec2" {
  ami           = var.ami_id
  security_groups = [aws_security_group.ec2-security-group.id]
  subnet_id     = aws_subnet.private_subnets[0].id
  instance_type = "t2.micro"
  key_name = "mykeypair"
  user_data = <<-EOF
    #!/bin/bash
    RDS_ENDPOINT="${aws_db_instance.mysql-rds.endpoint}"
    cat <<EOL > /var/www/inc/dbinfo.inc
    <?php
    define('DB_SERVER','${aws_db_instance.mysql-rds.endpoint}');
    define('DB_USERNAME', 'admin');
    define('DB_PASSWORD', 'Lolaboba123$');
    define('DB_DATABASE', 'db_web_2_tier');
    ?>
    EOL
    sudo systemctl start httpd
  EOF
  tags = {
    Name = "web_server-ec2"
}
}
