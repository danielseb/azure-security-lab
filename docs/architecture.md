# Security Lab Architecture

## Overview

This document provides a detailed technical overview of the Azure-based security lab architecture, including network topology, security controls, and component interactions.

## Architecture Diagram

```
Internet
    │
    │ (Your IP Only)
    ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Azure Subscription                          │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Resource Group: seclab-rg                    │  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────────────┐   │  │
│  │  │      Virtual Network: seclab-vnet (10.0.0.0/16)  │   │  │
│  │  │                                                    │   │  │
│  │  │  ┌─────────────────────────────────────────┐     │   │  │
│  │  │  │ Attacker Subnet (10.0.1.0/24)           │     │   │  │
│  │  │  │  ┌────────────────────────────────┐     │     │   │  │
│  │  │  │  │ Attacker VM                    │     │     │   │  │
│  │  │  │  │ - Ubuntu 22.04                 │     │     │   │  │
│  │  │  │  │ - Public IP: X.X.X.X          │     │     │   │  │
│  │  │  │  │ - Private IP: 10.0.1.4        │     │     │   │  │
│  │  │  │  │ - Tools: nmap, nikto, sqlmap  │     │     │   │  │
│  │  │  │  └────────────────────────────────┘     │     │   │  │
│  │  │  └───────────────┬─────────────────────────┘     │   │  │
│  │  │                  │                                 │   │  │
│  │  │  ┌───────────────┼─────────────────────────┐     │   │  │
│  │  │  │ Web Server Subnet (10.0.2.0/24)         │     │   │  │
│  │  │  │  ┌────────────▼──────────────────┐      │     │   │  │
│  │  │  │  │ Web Server VM                 │      │     │   │  │
│  │  │  │  │ - Ubuntu 22.04                │      │     │   │  │
│  │  │  │  │ - Private IP: 10.0.2.4        │      │     │   │  │
│  │  │  │  │ - Docker + Juice Shop:3000    │      │     │   │  │
│  │  │  │  │ - Filebeat (log shipper)      │      │     │   │  │
│  │  │  │  └────────────┬──────────────────┘      │     │   │  │
│  │  │  └───────────────┼─────────────────────────┘     │   │  │
│  │  │                  │ Logs                           │   │  │
│  │  │  ┌───────────────▼─────────────────────────┐     │   │  │
│  │  │  │ SIEM Subnet (10.0.3.0/24)               │     │   │  │
│  │  │  │  ┌──────────────────────────────────┐   │     │   │  │
│  │  │  │  │ SIEM VM                          │   │     │   │  │
│  │  │  │  │ - Ubuntu 22.04                   │   │     │   │  │
│  │  │  │  │ - Private IP: 10.0.3.4           │   │     │   │  │
│  │  │  │  │ - Elasticsearch:9200             │   │     │   │  │
│  │  │  │  │ - Kibana:5601                    │   │     │   │  │
│  │  │  │  └──────────────────────────────────┘   │     │   │  │
│  │  │  └─────────────────────────────────────────┘     │   │  │
│  │  │                                                    │   │  │
│  │  │  NAT Gateway (Outbound Internet)                  │   │  │
│  │  │    └─ Web Server & SIEM Subnets                   │   │  │
│  │  └──────────────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  Storage Account (Terraform State)                               │
│  ├─ Container: tfstate                                          │
│  └─ Blob: security-lab.tfstate                                  │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

## Network Architecture

### Virtual Network (VNet)

- **Name:** seclab-vnet
- **Address Space:** 10.0.0.0/16
- **Location:** UK South
- **Purpose:** Isolated network environment for the security lab

### Subnets

#### 1. Attacker Subnet (10.0.1.0/24)
- **Purpose:** Houses the attacker/penetration testing VM
- **Internet Access:** Direct via public IP
- **Connected To:** Web Server subnet, SIEM subnet
- **NSG Rules:**
  - Inbound SSH (22) from your IP only
  - Outbound to web server subnet (all ports)
  - Outbound to SIEM subnet (all ports)
  - Outbound to Internet

#### 2. Web Server Subnet (10.0.2.0/24)
- **Purpose:** Hosts the vulnerable web application (Juice Shop)
- **Internet Access:** Outbound only via NAT Gateway
- **Connected To:** SIEM subnet
- **NSG Rules:**
  - Inbound SSH (22) from attacker subnet only
  - Inbound HTTP (3000) from attacker subnet only
  - Outbound to SIEM (9200) for log shipping
  - Outbound to Internet via NAT (for updates)
  - Deny all other inbound traffic

#### 3. SIEM Subnet (10.0.3.0/24)
- **Purpose:** Hosts Elasticsearch and Kibana for log analysis
- **Internet Access:** Outbound only via NAT Gateway
- **Connected To:** Attacker subnet (for Kibana access)
- **NSG Rules:**
  - Inbound SSH (22) from attacker subnet only
  - Inbound Elasticsearch (9200) from web server subnet
  - Inbound Kibana (5601) from attacker subnet
  - Outbound to Internet via NAT (for updates)
  - Deny all other inbound traffic

### NAT Gateway

- **Purpose:** Provides outbound internet connectivity for web server and SIEM
- **Attached To:** Web server and SIEM subnets
- **Public IP:** Dynamically assigned
- **Use Cases:**
  - Package updates
  - Docker image pulls
  - Software installations
- **Security:** No inbound access allowed

## Components

### 1. Attacker VM

**Specifications:**
- **VM Size:** Standard_B2s (2 vCPU, 4GB RAM)
- **OS:** Ubuntu 22.04 LTS
- **Disk:** 30GB Standard SSD
- **Networking:** Public IP + Private IP (10.0.1.4)

**Installed Tools:**
- **Network Scanning:** nmap, netcat
- **Web Scanning:** nikto, dirb, gobuster, wfuzz
- **Exploitation:** sqlmap, Metasploit framework
- **Password Cracking:** john, hydra, hashcat
- **Proxy:** OWASP ZAP
- **Wordlists:** SecLists

**Purpose:**
- Entry point for accessing the lab
- Running security tests against Juice Shop
- Accessing Kibana for log analysis
- Jump box to other VMs

### 2. Web Server VM

**Specifications:**
- **VM Size:** Standard_B2s (2 vCPU, 4GB RAM)
- **OS:** Ubuntu 22.04 LTS
- **Disk:** 30GB Standard SSD
- **Networking:** Private IP only (10.0.2.4)

**Services:**
- **Docker:** Container runtime
- **Juice Shop:** OWASP vulnerable web application (port 3000)
- **Filebeat:** Log shipper to Elasticsearch

**OWASP Juice Shop:**
- Intentionally vulnerable web application
- Contains SQL injection, XSS, broken authentication, etc.
- Perfect for testing security tools
- Logs all HTTP requests

**Log Collection:**
- Docker container logs → Filebeat → Elasticsearch
- JSON format logs
- Includes HTTP requests, responses, errors
- Real-time log shipping

### 3. SIEM VM

**Specifications:**
- **VM Size:** Standard_D2s_v3 (2 vCPU, 8GB RAM)
- **OS:** Ubuntu 22.04 LTS
- **Disk:** 50GB Standard SSD
- **Networking:** Private IP only (10.0.3.4)

**Services:**
- **Elasticsearch 8.x:** Log storage and indexing (port 9200)
- **Kibana 8.x:** Web UI for log analysis (port 5601)

**Configuration:**
- Single-node cluster (lab environment)
- Security features disabled for simplicity
- JVM heap: 2GB (configurable)
- Data retention: 7 days (default)

**Purpose:**
- Centralized log collection
- Security event analysis
- Attack pattern identification
- Log correlation and search

## Security Architecture

### Defense in Depth

```
Layer 1: Network Segmentation
  ├─ Separate subnets for different functions
  └─ NSG rules enforce segmentation

Layer 2: Network Security Groups (NSGs)
  ├─ Whitelist approach (deny by default)
  ├─ Source IP restrictions
  └─ Port-specific rules

Layer 3: No Public Exposure
  ├─ Web server has no public IP
  ├─ SIEM has no public IP
  └─ Only attacker VM is internet-facing

Layer 4: SSH Key Authentication
  ├─ No password authentication
  ├─ 4096-bit RSA keys
  └─ Keys never stored in repository

Layer 5: Minimal Attack Surface
  ├─ Only required ports open
  ├─ Regular security updates
  └─ Minimal installed software
```

### Network Security Groups (NSGs)

#### Attacker NSG Rules

| Priority | Name | Direction | Protocol | Source | Dest | Port | Action |
|----------|------|-----------|----------|--------|------|------|--------|
| 100 | AllowSSH | Inbound | TCP | Your_IP/32 | Any | 22 | Allow |
| 110 | AllowWebServer | Outbound | Any | Any | 10.0.2.0/24 | Any | Allow |
| 120 | AllowSIEM | Outbound | Any | Any | 10.0.3.0/24 | Any | Allow |
| 130 | AllowInternet | Outbound | Any | Any | Internet | Any | Allow |
| 65000 | DenyAllInbound | Inbound | Any | Any | Any | Any | Deny |

#### Web Server NSG Rules

| Priority | Name | Direction | Protocol | Source | Dest | Port | Action |
|----------|------|-----------|----------|--------|------|------|--------|
| 100 | AllowSSHFromAttacker | Inbound | TCP | 10.0.1.0/24 | Any | 22 | Allow |
| 110 | AllowHTTPFromAttacker | Inbound | TCP | 10.0.1.0/24 | Any | 3000 | Allow |
| 120 | AllowSIEM | Outbound | TCP | Any | 10.0.3.0/24 | 9200 | Allow |
| 4096 | DenyAllInbound | Inbound | Any | Any | Any | Any | Deny |

#### SIEM NSG Rules

| Priority | Name | Direction | Protocol | Source | Dest | Port | Action |
|----------|------|-----------|----------|--------|------|------|--------|
| 100 | AllowSSHFromAttacker | Inbound | TCP | 10.0.1.0/24 | Any | 22 | Allow |
| 110 | AllowElasticsearch | Inbound | TCP | 10.0.2.0/24 | Any | 9200 | Allow |
| 120 | AllowKibanaFromAttacker | Inbound | TCP | 10.0.1.0/24 | Any | 5601 | Allow |
| 4096 | DenyAllInbound | Inbound | Any | Any | Any | Any | Deny |

### Access Patterns

```
You → Attacker VM (SSH with key)
  ├─→ Web Server VM (SSH)
  │   └─→ Juice Shop (HTTP:3000)
  │
  ├─→ SIEM VM (SSH)
  │   ├─→ Elasticsearch (HTTP:9200)
  │   └─→ Kibana (HTTP:5601)
  │
  └─→ Port Forwarding
      ├─→ Local:3000 → Web:3000 (Juice Shop)
      └─→ Local:5601 → SIEM:5601 (Kibana)
```

## Data Flow

### Log Collection Flow

```
1. User Request → Juice Shop
   │
   ▼
2. Juice Shop processes request
   │
   ▼
3. Docker logs request to /var/lib/docker/containers/
   │
   ▼
4. Filebeat reads Docker logs
   │
   ▼
5. Filebeat ships to Elasticsearch (10.0.3.4:9200)
   │
   ▼
6. Elasticsearch indexes logs
   │
   ▼
7. Kibana queries Elasticsearch
   │
   ▼
8. User views logs in Kibana UI
```

### Attack Flow Example

```
1. Attacker VM runs nmap scan
   nmap -sV 10.0.2.4
   │
   ▼
2. Juice Shop receives scan traffic
   │
   ▼
3. Logs generated in Docker
   │
   ▼
4. Filebeat ships to Elasticsearch
   │
   ▼
5. View scan activity in Kibana
   - Source IP: 10.0.1.4
   - Destination: 10.0.2.4:3000
   - Patterns: Port scan signatures
```

## Infrastructure as Code (IaC)

### Terraform Structure

```
terraform/
├── main.tf           # Provider, backend, resource group
├── network.tf        # VNet, subnets, NSGs, NAT gateway
├── compute.tf        # VMs, NICs, public IPs
├── variables.tf      # Input variables
├── outputs.tf        # Output values
└── cloud-init/       # VM initialization scripts
    ├── attacker-init.sh
    ├── webserver-init.sh
    └── siem-init.sh
```

### Terraform State Management

**Backend:** Azure Storage Account
- **Storage Account:** tfstate<random>
- **Container:** tfstate
- **Blob:** security-lab.tfstate
- **Features:**
  - Encryption at rest
  - Versioning enabled
  - Secure access (no public access)
  - State locking support

**Why Remote State?**
- Secure storage of infrastructure state
- Team collaboration support
- State locking prevents concurrent modifications
- Version history for rollback
- Separated from source code

### Cloud-Init Process

**Initialization Flow:**
```
VM Boot
  │
  ▼
Cloud-init executes
  │
  ├─→ System updates
  │
  ├─→ Package installation
  │
  ├─→ Service configuration
  │
  ├─→ Service startup
  │
  └─→ Create marker file (/var/log/cloud-init-complete)
```

**Timing:**
- Attacker VM: 5-7 minutes
- Web Server VM: 8-10 minutes (Docker pull)
- SIEM VM: 10-15 minutes (Elasticsearch initialization)

## DevSecOps Pipeline

### CI/CD Architecture

```
GitHub Repository
  │
  ├─→ [Push/PR] → Security Scanning Pipeline
  │   │
  │   ├─→ Secrets Detection (TruffleHog)
  │   ├─→ IaC Security (tfsec, Checkov)
  │   ├─→ Container Security (Trivy)
  │   └─→ Dependency Check (Snyk)
  │
  ├─→ [Manual] → Terraform Deploy Pipeline
  │   │
  │   ├─→ Azure Login
  │   ├─→ Terraform Init
  │   ├─→ Terraform Plan/Apply/Destroy
  │   └─→ Output Summary
  │
  └─→ [PR] → Cost Estimation Pipeline
      │
      ├─→ Infracost Analysis
      └─→ Post Comment on PR
```

### Security Scanning Tools

#### 1. TruffleHog
- **Purpose:** Detect leaked credentials
- **Scans:** Git history, code, comments
- **Finds:** API keys, passwords, tokens, certificates
- **Run:** On every push

#### 2. tfsec
- **Purpose:** Terraform security scanner
- **Checks:** 
  - Missing encryption
  - Open security groups
  - Public access settings
  - Insecure configurations
- **Run:** On every push

#### 3. Checkov
- **Purpose:** Policy-as-code scanner
- **Checks:**
  - CIS benchmarks
  - Industry best practices
  - Cloud-specific policies
- **Output:** SARIF format for GitHub Security
- **Run:** On every push

#### 4. Trivy
- **Purpose:** Container vulnerability scanner
- **Scans:** 
  - OS packages
  - Application dependencies
  - Known CVEs
- **Target:** Juice Shop Docker image
- **Severity:** Critical and High
- **Run:** On every push

#### 5. Snyk (Optional)
- **Purpose:** Dependency vulnerability management
- **Checks:** Open source vulnerabilities
- **Integrates:** With GitHub Security
- **Requires:** API token

### Pipeline Workflow Examples

#### Security Scan on Push

```yaml
Trigger: git push origin main
  │
  ▼
Job 1: Secrets Scan
  └─ ✓ No secrets found
  │
  ▼
Job 2: Terraform Security
  ├─ ✓ Terraform format check
  ├─ ✓ Terraform validate
  ├─ tfsec scan
  │   └─ ⚠ 2 warnings (acceptable for lab)
  └─ Checkov scan
      └─ ✓ Passed
  │
  ▼
Job 3: Container Security
  ├─ Trivy scan: juice-shop:latest
  │   ├─ 5 Critical vulnerabilities
  │   └─ 12 High vulnerabilities
  └─ Upload to GitHub Security
  │
  ▼
Job 4: Security Summary
  └─ Generate summary report
```

#### Manual Deployment

```yaml
Trigger: Manual workflow dispatch
  │
  ▼
Input: 
  - Action: apply
  - SSH IP: 203.0.113.45/32
  │
  ▼
Steps:
  1. Checkout code
  2. Setup Terraform
  3. Azure login (service principal)
  4. Terraform init
  5. Terraform plan
  6. Review plan
  7. Terraform apply
  8. Output connection details
```

## Cost Optimization

### Resource Costs (UK South)

| Resource | SKU | vCPU | RAM | Cost/Hour | Daily (8h) |
|----------|-----|------|-----|-----------|------------|
| Attacker VM | Standard_B2s | 2 | 4GB | £0.048 | £0.38 |
| Web Server VM | Standard_B2s | 2 | 4GB | £0.048 | £0.38 |
| SIEM VM | Standard_D2s_v3 | 2 | 8GB | £0.113 | £0.90 |
| NAT Gateway | Standard | - | - | £0.054 | £0.43 |
| Public IPs (2) | Standard | - | - | £0.008 | £0.06 |
| Storage (Disks) | Standard SSD | - | 110GB | £0.010 | £0.08 |
| Storage (State) | LRS | - | <1GB | £0.001 | £0.01 |
| **Total** | | | | **£0.282** | **£2.26** |

### Cost Optimization Strategies

1. **Use Burstable VMs (B-series)**
   - Lower cost than standard VMs
   - Good for lab workloads with variable usage
   - Accumulate credits when idle

2. **Destroy When Not in Use**
   ```bash
   terraform destroy
   ```
   - Zero cost when destroyed
   - Recreate in ~15 minutes

3. **Use Spot Instances (Advanced)**
   - Up to 90% discount
   - Risk of eviction
   - Good for non-critical labs

4. **Monitor Costs**
   ```bash
   az consumption usage list --start-date 2024-01-01 --end-date 2024-01-31
   ```

5. **Set Budget Alerts**
   - Azure Portal → Cost Management
   - Set alert at £10/month
   - Receive email notifications

## Scaling Considerations

### Vertical Scaling (Larger VMs)

**When to Scale Up:**
- SIEM VM struggling with log volume
- Web server slow under load
- More complex security testing

**How to Scale:**
```terraform
# In compute.tf
size = "Standard_D4s_v3"  # 4 vCPU, 16GB RAM
```

**Cost Impact:**
- 2x-3x cost increase per VM
- Better performance
- Handle more concurrent operations

### Horizontal Scaling (More VMs)

**Possible Extensions:**
- Additional web servers (different vulnerabilities)
- Multiple attacker VMs (different tool sets)
- Dedicated log forwarder VM
- Windows VM for Windows-specific testing

**Implementation:**
```terraform
# Add to compute.tf
resource "azurerm_linux_virtual_machine" "webserver2" {
  # Configuration for second web server
}
```

## Monitoring and Observability

### Built-in Monitoring

1. **Azure Monitor**
   - VM metrics (CPU, memory, disk, network)
   - Activity logs
   - Diagnostic logs

2. **Cloud-Init Logs**
   - `/var/log/cloud-init-output.log`
   - `/var/log/cloud-init-custom.log`

3. **Service Logs**
   - Docker: `sudo docker logs juiceshop`
   - Elasticsearch: `/var/log/elasticsearch/`
   - Kibana: `/var/log/kibana/`
   - Filebeat: `sudo journalctl -u filebeat`

### Monitoring Commands

```bash
# Check VM metrics
az monitor metrics list --resource /subscriptions/.../resourceGroups/seclab-rg/providers/Microsoft.Compute/virtualMachines/seclab-siem-vm

# View activity log
az monitor activity-log list --resource-group seclab-rg

# Check NSG flow logs (if enabled)
az network watcher flow-log show --nsg seclab-attacker-nsg --resource-group seclab-rg
```

## Backup and Disaster Recovery

### Not Implemented (Lab Environment)

**For Production:**
- VM snapshots
- Azure Backup
- Geo-redundant storage
- Multi-region deployment

**For This Lab:**
- Infrastructure is code (can be recreated)
- No persistent data to backup
- Destroy and recreate is the recovery strategy

## Security Hardening Options

### Current Security Posture

✅ **Implemented:**
- Network segmentation
- NSG rules (least privilege)
- SSH key authentication
- No public access to vulnerable systems
- Encrypted Terraform state

⚠️ **Not Implemented (Lab Simplifications):**
- No HTTPS/TLS certificates
- No intrusion detection system (IDS)
- No Web Application Firewall (WAF)
- Simplified logging (no audit logs)
- No DDoS protection
- Security features disabled in ELK

### Hardening for Production

If adapting this for production use:

```terraform
# Enable Azure Security Center
resource "azurerm_security_center_subscription_pricing" "vm" {
  tier          = "Standard"
  resource_type = "VirtualMachines"
}

# Enable Azure Defender
resource "azurerm_security_center_contact" "main" {
  email               = "security@example.com"
  alert_notifications = true
}

# Enable NSG Flow Logs
resource "azurerm_network_watcher_flow_log" "main" {
  # Configuration
}

# Add Application Gateway with WAF
resource "azurerm_application_gateway" "waf" {
  # Configuration
}
```

## Performance Tuning

### SIEM VM Optimization

**Elasticsearch Heap Size:**
```bash
# Adjust in /etc/elasticsearch/jvm.options.d/heap.options
# Use 50% of available RAM, max 32GB
-Xms4g
-Xmx4g
```

**Index Lifecycle Management:**
```bash
# Delete old indices to save space
curl -X DELETE "localhost:9200/filebeat-*-7-days-ago"
```

### Web Server Optimization

**Docker Resources:**
```bash
# Limit Juice Shop container resources
docker run -d \
  --name juiceshop \
  --memory="2g" \
  --cpus="1.5" \
  -p 3000:3000 \
  bkimminich/juice-shop:latest
```

## Future Enhancements

### Potential Additions

1. **Additional Vulnerable Apps**
   - DVWA (Damn Vulnerable Web Application)
   - WebGoat
   - Mutillidae

2. **Additional Security Tools**
   - Wazuh (Host IDS)
   - Suricata (Network IDS)
   - TheHive (Incident Response)

3. **Automation**
   - Automated attack scenarios
   - Scheduled vulnerability scans
   - Alert rules in Kibana

4. **Advanced Logging**
   - Windows Event Forwarding
   - Syslog collection
   - Cloud audit logs

5. **Training Environment**
   - CTF challenges
   - Guided attack scenarios
   - Documentation generation

## Compliance and Standards

### Alignment with Frameworks

**CIS Benchmarks:**
- Network segmentation ✓
- Encrypted storage ✓
- Minimal services ✓
- SSH key authentication ✓

**NIST Cybersecurity Framework:**
- Identify: Asset inventory via Terraform
- Protect: NSG rules, network segmentation
- Detect: SIEM log collection
- Respond: Manual incident response
- Recover: Infrastructure as code

**MITRE ATT&CK:**
- Useful for mapping attacks in Juice Shop
- Kibana queries for ATT&CK techniques
- Training for detection and response

## Conclusion

This architecture provides a secure, isolated environment for:
- Learning security monitoring
- Testing security tools
- Understanding log analysis
- Practicing DevSecOps
- Building a portfolio project

**Key Strengths:**
- Fully automated deployment
- Security by design
- Cost-effective
- Easy to destroy and recreate
- Industry-standard tools

**Limitations:**
- Lab environment only
- Simplified security (no TLS, etc.)
- Limited scalability
- No high availability
- No disaster recovery

**Best Use Cases:**
- Security training
- Tool testing
- Portfolio demonstration
- DevSecOps practice
- Log analysis learning

---

**Document Version:** 1.0  
**Last Updated:** 30/10/2025  
**Author:** Daniel Sebastian