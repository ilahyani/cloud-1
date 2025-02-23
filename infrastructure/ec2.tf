resource "aws_instance" "inception" {
  ami                    = "ami-005fc0f236362e99f"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_connection.id]
  key_name               = aws_key_pair.inception_key.key_name
  count                  = var.instance_count
  
  tags = {
    Name = "inception"
  }

  depends_on = [local_file.private_key_pem]
}

resource "aws_security_group" "allow_connection" {
  name_prefix = "allow_connection"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # cidr_blocks = var.ip_address
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "tls_private_key" "ssh_key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "inception_key" {
  key_name   = "inception_key"
  public_key = tls_private_key.ssh_key_pair.public_key_openssh
}

resource "local_file" "private_key_pem" {
  content  = tls_private_key.ssh_key_pair.private_key_pem
  filename = "${path.module}/aws_ec2_key.pem"
}

resource "null_resource" "set_permissions" {
  provisioner "local-exec" {
    command = "chmod 600 ${path.module}/aws_ec2_key.pem"
  }

  depends_on = [local_file.private_key_pem]
}

resource "local_file" "ansible_hosts_inventory" {
  filename = "${path.module}/ansible/inventory"
  content = <<EOT
[inception]
${join("\n", [for instance in aws_instance.inception : "${instance.public_ip} ansible_ssh_user=ubuntu ansible_ssh_private_key_file=${path.module}/aws_ec2_key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'"])}
EOT
}

output "public_ip" {
  value = [for instance in aws_instance.inception : instance.public_ip]
}
