provider "aws" {
  region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "rafs_tf_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.rafs_tf_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet"
  }
}

# Create private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.rafs_tf_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b" 

  tags = {
    Name = "Private Subnet"
  }
}

# Create a security group
resource "aws_security_group" "rafs_security_group" {
  vpc_id = aws_vpc.rafs_tf_vpc.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH from anywhere
  }
}

# Create an EC2 instance in the private subnet
resource "aws_instance" "rafs_tf_instance" {
  ami             = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI 
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.private_subnet.id
  security_group  = [aws_security_group.rafs_security_group.id]

  key_name        = "your-key-pair-name" # Change this 

  tags = {
    Name = "MyEC2Instance"
  }
}

# Create an S3 bucket
resource "aws_s3_bucket" "rafs-log-bucket" {
  bucket = "rafs-log-bucket" 
  acl    = "private"
}

# Modify the EC2 instance resource to include IAM role
resource "aws_instance" "rafs_tf_instance" {
  ami             = "ami-0c55b159cbfafe1f0"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.private_subnet.id
  security_group  = [aws_security_group.my_security_group.id]
  iam_instance_profile = aws_iam_instance_profile.my_instance_profile.name # Assign IAM role to EC2 instance

  key_name        = "your-key-pair-name"

  tags = {
    Name = "MyEC2Instance"
  }
}

# Create an IAM role and instance profile for EC2
resource "aws_iam_role" "my_iam_role" {
  name = "EC2S3AccessRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "my_instance_profile" {
  name = "EC2S3AccessInstanceProfile"
  role = aws_iam_role.my_iam_role.name
}

# Attach an inline policy to the IAM role for read-only access to the S3 bucket
resource "aws_iam_role_policy" "my_iam_policy" {
  name        = "S3ReadOnlyAccess"
  role        = aws_iam_role.my_iam_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": ["${aws_s3_bucket.rafs_s3_bucket.arn}/*"]
    }
  ]
}
EOF
}

# Configure the EC2 instance to send logs to the S3 bucket
resource "aws_instance" "my_instance" {
  ami             = "ami-0c55b159cbfafe1f0"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.private_subnet.id
  security_group  = [aws_security_group.rafs_security_group.id]
  iam_instance_profile = aws_iam_instance_profile.my_instance_profile.name

  key_name        = "your-key-pair-name"

  user_data = <<-EOF
              #!/bin/bash
              echo 'export AWS_DEFAULT_REGION=us-east-1' >> /etc/environment
              aws s3 cp /var/log/nginx/access.log s3://${aws_s3_bucket.rafs_s3_bucket.bucket}/nginx/access.log
              EOF

  tags = {
    Name = "MyEC2Instance"
  }
}
