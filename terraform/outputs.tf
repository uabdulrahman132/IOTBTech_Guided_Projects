output "master_public_ip" {
  description = "Public IP of the master node (runs Ansible)."
  value       = aws_instance.master.public_ip
}

output "control_public_ip" {
  description = "Public IP of the control node (target of the playbook)."
  value       = aws_instance.control.public_ip
}

output "ssh_master" {
  description = "SSH into the master node. The Ansible setup finishes a couple of minutes after apply."
  value       = "ssh -i ${var.ssh_private_key_path} ${local.ssh_user}@${aws_instance.master.public_ip}"
}

output "app_url" {
  description = "URL served by the Nginx container after running the playbook on the master node."
  value       = "http://${aws_instance.control.public_ip}"
}
