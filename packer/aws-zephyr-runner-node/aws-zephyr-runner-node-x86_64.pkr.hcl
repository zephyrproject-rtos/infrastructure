packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "zephyr_runner_node_x86_64" {
  region        = "us-east-2"
  ami_name      = "zephyr-runner-node-x86_64-{{timestamp}}"
  source_ami    = "ami-0fcd72f3118e0dd88" # amazon-eks-node-1.23-v20221112
  instance_type = "c5a.xlarge"
  ssh_username  = "ec2-user"
  launch_block_device_mappings {
    device_name = "/dev/xvda"
    volume_size = 120
    volume_type = "gp3"
    iops        = 3000
    throughput  = 125
    delete_on_termination = true
  }
}

build {
  name = "zephyr-runner-node-x86_64"
  sources = ["source.amazon-ebs.zephyr_runner_node_x86_64"]

  provisioner "shell" {
    script       = "script.sh"
    pause_before = "10s"
    timeout      = "1800s"
  }
}
