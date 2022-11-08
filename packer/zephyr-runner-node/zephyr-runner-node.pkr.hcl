packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "zephyr_runner_node" {
  region        = "us-east-2"
  ami_name      = "zephyr-runner-node-{{timestamp}}"
  source_ami    = "ami-06acc29adf84c8f3c" # amazon-eks-node-1.23
  instance_type = "c5a.xlarge"
  ssh_username  = "ec2-user"
  launch_block_device_mappings {
    device_name = "/dev/xvda"
    volume_size = 80
    volume_type = "gp3"
    iops        = 3000
    throughput  = 125
    delete_on_termination = true
  }
}

build {
  name = "zephyr-runner-node"
  sources = ["source.amazon-ebs.zephyr_runner_node"]

  provisioner "shell" {
    script       = "script.sh"
    pause_before = "10s"
    timeout      = "1800s"
  }
}
