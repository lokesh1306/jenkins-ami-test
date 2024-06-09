packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "DH_TOKEN" {
  default = ""
}
variable "GH_USERNAME" {
  default = ""
}
variable "GH_TOKEN" {
  default = ""
}

variable "name" {
  type    = string
  default = "csye7125_jenkins"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "Region where EC2 should be deployed for packer"
}

variable "profile" {
  type    = string
  default = "infra"
}

variable "source_ami" {
  type    = string
  default = "ami-04b70fa74e45c3917" # Ubuntu 24.04 LTS
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "ami_users" {
  type    = list(string)
  default = ["385861399472", "209538387374", "307298369337"]
}

source "amazon-ebs" "jenkins" {
  profile               = var.profile
  ami_name              = "csye7125_jenkins"
  ami_description       = "AMI for CSYE 7125"
  region                = var.region
  ami_users             = var.ami_users
  force_deregister      = true
  force_delete_snapshot = true

  aws_polling {
    delay_seconds = 120
    max_attempts  = 50
  }

  instance_type = var.instance_type
  source_ami    = var.source_ami
  ssh_username  = var.ssh_username

  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/xvda"
    volume_size           = 10
    volume_type           = "gp2"
  }
  tags = {
    Name = var.name
  }
}

build {
  sources = ["source.amazon-ebs.jenkins"]

  provisioner "shell" {
    inline = [
      "echo DH_USERNAME=${var.DH_USERNAME} | sudo tee -a /etc/environment",
      "echo DH_TOKEN=${var.DH_TOKEN} | sudo tee -a /etc/environment",
      "echo GH_USERNAME=${var.GH_USERNAME} | sudo tee -a /etc/environment",
      "echo GH_TOKEN=${var.GH_TOKEN} | sudo tee -a /etc/environment",
    ]
  }

  provisioner "shell" {
    environment_vars = [
      "CHECKPOINT_DISABLE=1"
    ]
    scripts = [
      "packer_init.sh"
    ]
  }

  provisioner "file" {
    source      = "jenkins_nginx_final.conf"
    destination = "/home/ubuntu/jenkins_nginx_final.conf"
  }

  provisioner "file" {
    source      = "jenkins_nginx_initial.conf"
    destination = "/home/ubuntu/jenkins_nginx_initial.conf"
  }

  provisioner "file" {
    source      = "certbot_initial.sh"
    destination = "/home/ubuntu/certbot_initial.sh"
  }

  provisioner "file" {
    source      = "certbot_renewal.sh"
    destination = "/home/ubuntu/certbot_renewal.sh"
  }

  provisioner "file" {
    source      = "01-credentials.groovy"
    destination = "/home/ubuntu/01-credentials.groovy"
  }

  provisioner "file" {
    source      = "04-seedJob.groovy"
    destination = "/home/ubuntu/04-seedJob.groovy"
  }

  provisioner "file" {
    source      = "03-approval.groovy"
    destination = "/home/ubuntu/03-approval.groovy"
  }

  provisioner "file" {
    source      = "seed.groovy"
    destination = "/home/ubuntu/seed.groovy"
  }

  provisioner "shell" {
    environment_vars = [
      "CHECKPOINT_DISABLE=1"
    ]
    scripts = [
      "packer_complete.sh"
    ]
  }
}