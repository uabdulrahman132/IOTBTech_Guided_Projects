output "control_public_ip" {
  description = "Public IP of the control node (runs Ansible)."
  value       = aws_instance.control.public_ip
}

output "managed_public_ip" {
  description = "Public IP of the managed node (target of the playbook)."
  value       = aws_instance.managed.public_ip
}

output "ssh_control" {
  description = "SSH into the control node. The Ansible setup finishes a couple of minutes after apply."
  value       = "ssh -i ${var.ssh_private_key_path} ${local.ssh_user}@${aws_instance.control.public_ip}"
}

output "app_url" {
  description = "URL served by the Nginx container after running the playbook on the control node."
  value       = "http://${aws_instance.managed.public_ip}"
}
