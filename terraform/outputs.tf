output "attacker_public_ip" {
  description = "Public IP address of the attacker VM"
  value       = azurerm_public_ip.attacker.ip_address
}

output "attacker_private_ip" {
  description = "Private IP address of the attacker VM"
  value       = azurerm_network_interface.attacker.private_ip_address
}

output "webserver_private_ip" {
  description = "Private IP address of the web server VM"
  value       = azurerm_network_interface.webserver.private_ip_address
}

output "siem_private_ip" {
  description = "Private IP address of the SIEM VM"
  value       = azurerm_network_interface.siem.private_ip_address
}

output "ssh_command_attacker" {
  description = "SSH command to connect to attacker VM"
  value       = "ssh -i ~/.ssh/azure_lab_key ${var.admin_username}@${azurerm_public_ip.attacker.ip_address}"
}

output "juice_shop_url" {
  description = "Juice Shop URL (accessible from attacker VM)"
  value       = "http://${azurerm_network_interface.webserver.private_ip_address}:3000"
}

output "kibana_url" {
  description = "Kibana URL (accessible from attacker VM)"
  value       = "http://${azurerm_network_interface.siem.private_ip_address}:5601"
}

output "port_forward_juice_shop" {
  description = "Command to port forward Juice Shop to local machine"
  value       = "ssh -i ~/.ssh/azure_lab_key -L 3000:${azurerm_network_interface.webserver.private_ip_address}:3000 ${var.admin_username}@${azurerm_public_ip.attacker.ip_address}"
}

output "port_forward_kibana" {
  description = "Command to port forward Kibana to local machine"
  value       = "ssh -i ~/.ssh/azure_lab_key -L 5601:${azurerm_network_interface.siem.private_ip_address}:5601 ${var.admin_username}@${azurerm_public_ip.attacker.ip_address}"
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.lab.name
}

output "deployment_complete_message" {
  description = "Message to display after deployment"
  value       = <<-EOT
  
  ========================================
  🎉 Lab Deployment Complete!
  ========================================
  
  Attacker VM IP: ${azurerm_public_ip.attacker.ip_address}
  
  Connect to Attacker VM:
    ssh -i ~/.ssh/azure_lab_key ${var.admin_username}@${azurerm_public_ip.attacker.ip_address}
  
  From Attacker VM, access:
    - Web Server: ssh ${var.admin_username}@${azurerm_network_interface.webserver.private_ip_address}
    - SIEM: ssh ${var.admin_username}@${azurerm_network_interface.siem.private_ip_address}
    - Juice Shop: http://${azurerm_network_interface.webserver.private_ip_address}:3000
    - Kibana: http://${azurerm_network_interface.siem.private_ip_address}:5601
  
  Port Forwarding (from your local machine):
    Juice Shop: ssh -i ~/.ssh/azure_lab_key -L 3000:${azurerm_network_interface.webserver.private_ip_address}:3000 ${var.admin_username}@${azurerm_public_ip.attacker.ip_address}
    Kibana: ssh -i ~/.ssh/azure_lab_key -L 5601:${azurerm_network_interface.siem.private_ip_address}:5601 ${var.admin_username}@${azurerm_public_ip.attacker.ip_address}
  
  ⚠️  Note: VMs may take 5-10 minutes to complete initialization
  
  Check VM status: ./scripts/check-deployment.sh
  
  ========================================
  EOT
}