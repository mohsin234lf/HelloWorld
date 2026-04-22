Objective:
Installing k3s on a Linux machine and automate the deployment of a "Hello World" Nginx application using a Git pipeline. We wil be using terraform for installing k3s on linux instance. After installing k3s configuring a Git pipeline to automatically deploy the application to the cluster.

Steps:

Part 1: Installing k3s on a Linux Machine
Automation script to install k3s on a Linux machine using Terraform
Used Terraform to provision the linux instance (the EC2 instance) and used startup script that runs automatically when the VM boots, installing k3s without manual intervention.

Code:
------------------------------------------------------------------------
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
----------------------------------------------------------------------------

Part 2: Deploying "Hello World" Nginx Application

A yaml file for deploying the Nginx "Hello World" application. Which 
1. Creates a static HTML page via ConfigMap.
2. Deploys Nginx to serve that page.
3. Exposes it externally using a NodePort service.

Code:
----------------------------------------------------------------------------
apiVersion: v1
kind: ConfigMap
metadata:
  name: hello-html
data:
  index.html: |
    <html>
      <head><title>Hello</title></head>
      <body>
        <h1>Hello World</h1>
      </body>
    </html>

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-hello
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-hello
  template:
    metadata:
      labels:
        app: nginx-hello
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html-volume
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html-volume
        configMap:
          name: hello-html

---
apiVersion: v1
kind: Service
metadata:
  name: nginx-hello-service
spec:
  type: NodePort
  selector:
    app: nginx-hello
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30007
---------------------------------------------------------------------------

Part 3: Setting Up Git Pipeline for Automatic Deployment

On every push to main branch, GitHub Actions triggers a workflow that sets up kubeconfig securely using secrets, connects to the k3s cluster via API server, and applies Kubernetes manifests using kubectl.

Code:
---------------------------------------------------------------------------
name: Deploy to K3s

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v4   

    - name: Install kubectl
      run: |
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/

    - name: Set up kubeconfig
      run: |
        mkdir -p $HOME/.kube
        echo "${{ secrets.KUBECONFIG_DATA }}" > $HOME/.kube/config
        chmod 600 $HOME/.kube/config

    - name: Test cluster connection
      run: kubectl get nodes

    - name: Deploy application
      run: kubectl apply -f nginx-hello.yaml
