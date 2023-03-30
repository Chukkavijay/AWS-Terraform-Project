provider "aws" {}

resource "aws_vpc" "rbc_vpc" {
    cidr_block = var.vpc_cidr_block
    tags = {
        Name = "${var.env}-vpc"
    }
}

resource "aws_subnet" "rbc-sn-1" {
    vpc_id = aws_vpc.rbc_vpc.id
    cidr_block = var.sn-cidr-block
    availability_zone = var.az
    tags = {
        Name = "${var.env}-subnet-1"
    }
}

resource "aws_internet_gateway" "rbc-igw" {
    vpc_id = aws_vpc.rbc_vpc.id
    tags = {
        Name = "${var.env}-igw"
    }
}

resource "aws_route_table" "rbc-rt" {
    vpc_id = aws_vpc.rbc_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.rbc-igw.id
    }
    tags = {
        Name = "${var.env}-rtb"
    }
}

resource "aws_route_table_association" "rbc-rt-subnet" {
  subnet_id      = aws_subnet.rbc-sn-1.id
  route_table_id = aws_route_table.rbc-rt.id
}


resource "aws_security_group" "rbc-sg" {
  name   = "rbc-sg"
  vpc_id = aws_vpc.rbc_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.env}-sg"
  }
}


data "aws_ami" "amazon-linux-image" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

output "ami_id" {
  value = data.aws_ami.amazon-linux-image.id
}


resource "aws_instance" "rbc-server" {
  ami                         = data.aws_ami.amazon-linux-image.id
  instance_type               = "t2.micro"
  key_name                    = "AWSKEY"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.rbc-sn-1.id
  vpc_security_group_ids      = [aws_security_group.rbc-sg.id]
  availability_zone			  = var.az

  tags = {
    Name = "${var.env}-server"
  }

  user_data = <<EOF
                 #!/bin/bash
                 yum update && yum install -y docker 
                 systemctl start docker
                 usermod -aG docker ec2-user
                 docker run -p 8080:8080 nginx &
              EOF

}


