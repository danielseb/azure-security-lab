# Troubleshooting Guide

This guide covers common issues you might encounter and how to resolve them.

## Table of Contents

- [Deployment Issues](#deployment-issues)
- [Connectivity Issues](#connectivity-issues)
- [Service Issues](#service-issues)
- [Terraform Issues](#terraform-issues)
- [Azure Issues](#azure-issues)
- [Performance Issues](#performance-issues)

---

## Deployment Issues

### Issue: Terraform Apply Fails with "IP Address Required"

**Error:**
```
Error: Missing required argument
The argument "allowed_ssh_ip" is required, but no definition was found.
```

**Solution:**
```bash
# Get your public IP
MY_IP=$(curl -s ifconfig.me)

# Apply with the variable
terraform apply -var="allowed_ssh_ip=${MY_IP}/32"
```

### Issue: Backend Initialization Fails

**Error:**
```
Error: Failed to get existing workspaces: storage: service returned error: StatusCode=404
```

**Solution:**
1. Run the backend setup script:
```bash
./scripts/setup-backend.sh
```

2. Update `main.tf` with the backend configuration from `backend-config.txt`

3. Re-initialize:
```bash
cd terraform
terraform init
```

### Issue: Quota Exceeded

**Error:**
```
Error: Error creating Virtual Machine: compute.VirtualMachinesClient#CreateOrUpdate: 
Failure responding to request: StatusCode=409 -- Original Error: autorest/azure: 
Service returned an error. Status=409 Code="OperationNotAllowed" Message="Operation could not be completed as it results in exceeding approved standardDSv3Family Cores quota."
```

**Solution:**
1. Check your quota in Azure Portal:
   - Go to Subscriptions → Usage + quotas
   - Search for "Standard DSv3 Family vCPUs"

2. Options:
   - Request a quota increase in Azure Portal
   - Or change VM sizes in `compute.tf` to B-series:
```terraform
size = "Standard_B2ms"  # Instead of Standard_D2s_v3
```

### Issue: VM Initialization Takes Too Long

**Symptoms:**
- Services not accessible after 10+ minutes
- Cloud-init appears to be stuck

**Solution:**
1. SSH into the VM:
```bash
ssh -i ~/.ssh/azure_lab_key azureuser@<VM_IP>
```

2. Check cloud-init status:
```bash
# Check if cloud-init is still running
sudo cloud-init status

# View cloud-init logs
sudo tail -f /var/log/cloud-init-output.log

# Check custom initialization log
sudo tail -f /var/log/cloud-init-custom.log
```

3. If stuck, you can manually complete initialization:
```bash
# For web server
sudo docker ps
sudo systemctl status filebeat

# For SIEM
sudo systemctl status elasticsearch
sudo systemctl status kibana
```

---

## Connectivity Issues

### Issue: Cannot SSH to Attacker VM

**Error:**
```
ssh: connect to host X.X.X.X port 22: Connection refused
```

**Solution:**

1. Verify your IP hasn't changed:
```bash
curl ifconfig.me
```

2. Update NSG rule if IP changed:
```bash
cd terraform
terraform apply -var="allowed_ssh_ip=$(curl -s ifconfig.me)/32"
```

3. Check NSG rules in Azure Portal:
   - Go to Network Security Groups
   - Check inbound rules allow your IP on port 22

4. Verify VM is running:
```bash
az vm list -g seclab-rg --output table
az vm get-instance-view -g seclab-rg -n seclab-attacker-vm --query instanceView.statuses
```

### Issue: Cannot Access Juice Shop from Attacker VM

**Error:**
```
curl: (7) Failed to connect to 10.0.2.4 port 3000: Connection refused
```

**Solution:**

1. SSH to web server from attacker VM:
```bash
ssh azureuser@10.0.2.4
```

2. Check Docker container status:
```bash
sudo docker ps
sudo docker logs juiceshop
```

3. If container is not running:
```bash
sudo docker start juiceshop
```

4. If container doesn't exist:
```bash
sudo docker run -d --name juiceshop --restart unless-stopped -p 3000:3000 bkimminich/juice-shop:latest
```

### Issue: Cannot Access Kibana

**Error:**
```
curl: (7) Failed to connect to 10.0.3.4 port 5601: Connection refused
```

**Solution:**

1. SSH to SIEM VM:
```bash
ssh azureuser@10.0.3.4
```

2. Check Kibana status:
```bash
sudo systemctl status kibana
sudo journalctl -u kibana -f
```

3. Check Elasticsearch (Kibana dependency):
```bash
sudo systemctl status elasticsearch
curl http://localhost:9200
```

4. Restart services if needed:
```bash
sudo systemctl restart elasticsearch
sleep 30
sudo systemctl restart kibana
```

### Issue: Port Forwarding Not Working

**Error:**
```
channel 2: open failed: connect failed: Connection refused
```

**Solution:**

1. Verify the service is running on the target VM first

2. Check SSH command syntax:
```bash
# Correct format
ssh -i ~/.ssh/azure_lab_key -L 3000:10.0.2.4:3000 azureuser@<ATTACKER_IP>

# Not this (missing attacker VM IP)
ssh -i ~/.ssh/azure_lab_key -L 3000:10.0.2.4:3000
```

3. Try with verbose output:
```bash
ssh -v -i ~/.ssh/azure_lab_key -L 3000:10.0.2.4:3000 azureuser@<ATTACKER_IP>
```

---

## Service Issues

### Issue: Juice Shop Container Keeps Restarting

**Solution:**

1. Check container logs:
```bash
sudo docker logs juiceshop --tail 100
```

2. Check system resources:
```bash
free -h
df -h
```

3. If out of memory, increase VM size in `compute.tf`:
```terraform
size = "Standard_B2ms"  # 8GB RAM instead of 4GB
```

### Issue: Elasticsearch Won't Start

**Error:**
```
bootstrap check failure [1] of [1]: max virtual memory areas vm.max_map_count [65530] is too low
```

**Solution:**

1. This should be set by cloud-init, but if not:
```bash
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

2. Restart Elasticsearch:
```bash
sudo systemctl restart elasticsearch
```

### Issue: No Logs Appearing in Kibana

**Solution:**

1. Check Filebeat on web server:
```bash
ssh azureuser@10.0.2.4
sudo systemctl status filebeat
sudo filebeat test output
```

2. Check Elasticsearch indices on SIEM:
```bash
ssh azureuser@10.0.3.4
curl http://localhost:9200/_cat/indices?v
```

3. Restart Filebeat:
```bash
ssh azureuser@10.0.2.4
sudo systemctl restart filebeat
```

4. Create index pattern in Kibana:
```bash
ssh azureuser@10.0.3.4
/home/azureuser/setup-kibana.sh
```

### Issue: Kibana Shows "Kibana server is not ready yet"

**Solution:**

1. Wait 5-10 minutes after deployment (Kibana takes time to start)

2. Check Kibana logs:
```bash
sudo journalctl -u kibana -n 100
```

3. Check Elasticsearch connection:
```bash
curl http://10.0.3.4:9200
```

4. Restart Kibana:
```bash
sudo systemctl restart kibana
```

---

## Terraform Issues

### Issue: State Lock Error

**Error:**
```
Error: Error acquiring the state lock
```

**Solution:**

1. If previous operation was interrupted:
```bash
terraform force-unlock <LOCK_ID>
```

2. If using Azure backend:
```bash
# Check for lease
az storage blob show --account-name <STORAGE_ACCOUNT> --container-name tfstate --name security-lab.tfstate --query properties.lease
```

### Issue: Resource Already Exists

**Error:**
```
Error: A resource with the ID already exists
```

**Solution:**

1. Import the existing resource:
```bash
terraform import azurerm_resource_group.lab /subscriptions/<SUB_ID>/resourceGroups/seclab-rg
```

2. Or remove from state and let Terraform recreate:
```bash
terraform state rm azurerm_resource_group.lab
terraform apply
```

### Issue: Terraform Destroy Fails

**Error:**
```
Error: Error deleting Resource Group: resources.GroupsClient#Delete: 
Failure sending request: StatusCode=0 -- Original Error: context deadline exceeded
```

**Solution:**

1. Manually delete stuck resources in Azure Portal

2. Force remove from state:
```bash
terraform state rm <RESOURCE_ADDRESS>
```

3. Try destroying specific resources:
```bash
terraform destroy -target=azurerm_linux_virtual_machine.attacker
```

---

## Azure Issues

### Issue: Insufficient Permissions

**Error:**
```
Error: authorization.RoleAssignmentsClient#Create: 
Failure responding to request: StatusCode=403
```

**Solution:**

1. Check your Azure role:
```bash
az role assignment list --assignee $(az account show --query user.name -o tsv)
```

2. You need at least "Contributor" role on the subscription

3. Contact your Azure admin to grant proper permissions

### Issue: Region Not Available

**Error:**
```
Error: The requested VM size is not available in the current region
```

**Solution:**

1. Check available VM sizes in region:
```bash
az vm list-skus --location uksouth --output table | grep Standard_D2s_v3
```

2. Change region in `variables.tf`:
```terraform
variable "location" {
  default = "ukwest"  # Try different region
}
```

3. Or use different VM size:
```terraform
size = "Standard_B2s"
```

### Issue: Subscription Not Registered for Resource Provider

**Error:**
```
Error: Code="MissingSubscriptionRegistration" 
Message="The subscription is not registered to use namespace 'Microsoft.Compute'"
```

**Solution:**

```bash
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Storage

# Check registration status
az provider show --namespace Microsoft.Compute --query registrationState
```

---

## Performance Issues

### Issue: VMs Running Slowly

**Solution:**

1. Check VM metrics in Azure Portal:
   - CPU utilization
   - Memory usage
   - Disk I/O

2. Upgrade VM sizes in `compute.tf`:
```terraform
# For SIEM (needs more resources)
size = "Standard_D4s_v3"  # 4 vCPU, 16GB RAM

# For web server
size = "Standard_B2ms"    # 2 vCPU, 8GB RAM
```

3. Apply changes:
```bash
terraform apply
```

**Note:** This will recreate the VMs!

### Issue: Elasticsearch Using Too Much Memory

**Solution:**

1. Adjust JVM heap size on SIEM VM:
```bash
sudo nano /etc/elasticsearch/jvm.options.d/heap.options
```

2. Set to 50% of available RAM:
```
-Xms2g
-Xmx2g
```

3. Restart:
```bash
sudo systemctl restart elasticsearch
```

### Issue: Network Latency

**Solution:**

1. Ensure all VMs are in the same region

2. Check NSG rules aren't being overly restrictive

3. Verify VMs are in correct subnets:
```bash
az network nic show --ids $(az vm show -g seclab-rg -n seclab-attacker-vm --query networkProfile.networkInterfaces[0].id -o tsv) --query ipConfigurations[0].subnet.id
```

---

## General Debugging Commands

### Check All VM Status

```bash
cd terraform

# Get all outputs
terraform output

# List all VMs
az vm list -g seclab-rg --output table

# Check VM power state
az vm get-instance-view -g seclab-rg -n seclab-attacker-vm --query instanceView.statuses
az vm get-instance-view -g seclab-rg -n seclab-webserver-vm --query instanceView.statuses
az vm get-instance-view -g seclab-rg -n seclab-siem-vm --query instanceView.statuses
```

### View Cloud-Init Logs

```bash
# SSH to any VM
ssh -i ~/.ssh/azure_lab_key azureuser@<VM_IP>

# Check cloud-init status
cloud-init status --long

# View initialization logs
sudo cat /var/log/cloud-init-output.log
sudo cat /var/log/cloud-init-custom.log

# Check if initialization completed
ls -la /var/log/cloud-init-complete
```

### Test Network Connectivity

```bash
# From attacker VM
ssh -i ~/.ssh/azure_lab_key azureuser@<ATTACKER_IP>

# Test web server connectivity
ping -c 3 10.0.2.4
nc -zv 10.0.2.4 3000
curl -I http://10.0.2.4:3000

# Test SIEM connectivity
ping -c 3 10.0.3.4
nc -zv 10.0.3.4 9200
nc -zv 10.0.3.4 5601
curl http://10.0.3.4:9200
```

### Check Azure Resource Status

```bash
# List all resources
az resource list -g seclab-rg --output table

# Check NSG rules
az network nsg rule list -g seclab-rg --nsg-name seclab-attacker-nsg --output table

# Check VNet configuration
az network vnet show -g seclab-rg -n seclab-vnet

# View activity log
az monitor activity-log list -g seclab-rg --max-events 50
```

---

## Getting Help

If you're still experiencing issues:

1. **Check the logs** - Most issues can be diagnosed from logs
2. **Run check script** - `./scripts/check-deployment.sh`
3. **Review Azure Portal** - Check resource status and activity logs
4. **GitHub Issues** - Check if others have reported similar issues
5. **Azure Documentation** - Search for specific error messages

## Emergency Recovery

If everything is broken and you want to start fresh:

```bash
# Complete teardown
cd terraform
terraform destroy -auto-approve

# Clean local state
rm -rf .terraform terraform.tfstate*

# Start over
terraform init
terraform apply
```

**Remember:** Destroying infrastructure loses all data and configuration!

---

## Prevention Tips

1. **Always wait 10 minutes** after deployment before troubleshooting
2. **Check your IP hasn't changed** before reporting SSH issues
3. **Monitor costs** in Azure Portal to avoid surprises
4. **Destroy when done** to prevent ongoing charges
5. **Keep backups** of your SSH keys and important configurations
6. **Document changes** if you customize the setup
7. **Test in stages** - Deploy one VM at a time if having issues

---

**Last Updated:** Use these solutions as a starting point. Azure and Terraform are regularly updated, so some commands may need adjustment for newer versions.