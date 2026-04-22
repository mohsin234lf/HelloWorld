provider "aws" {
  region = "us-east-1"
}

variable "key_name" {
  default = "keypair"
}

resource "aws_instance" "k3s_server" {
  ami           = "ami-098e39bafa7e7303d"
  instance_type = "t3.micro"
  key_name      = var.key_name

  # Existing Security Group
  vpc_security_group_ids = ["sg-0591837bebe422401"]

  user_data = <<-EOF
              #!/bin/bash

              exec > /var/log/user-data.log 2>&1
              dnf update -y
              dnf install -y curl
              systemctl disable firewalld --now
              curl -sfL https://get.k3s.io | sh -
              sleep 30
              mkdir -p /root/.kube
              cp /etc/rancher/k3s/k3s.yaml /root/.kube/config
              chmod 600 /root/.kube/config
              EOF
  tags = {
    Name = "k3s-server"
  }
}

output "public_ip" {
  value = aws_instance.k3s_server.public_ip
}
