output "instance_public_ip" {
  value = aws_instance.gardener_devbox.public_ip
}

output "ssh_command" {
  value = "ssh ubuntu@${aws_instance.gardener_devbox.public_ip}"
}
