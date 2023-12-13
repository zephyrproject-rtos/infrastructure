packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "zephyr_runner_node_arm64" {
  region        = "us-east-2"
  ami_name      = "zephyr-runner-node-arm64-{{timestamp}}"
  source_ami    = "ami-08577b6b086f201e0" # amazon-eks-arm64-node-1.23-v20221112
  instance_type = "c6g.xlarge"
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
  name = "zephyr-runner-node-arm64"
  sources = ["source.amazon-ebs.zephyr_runner_node_arm64"]

  provisioner "shell" {
    script       = "script.sh"
    pause_before = "10s"
    timeout      = "1800s"
  }
}
