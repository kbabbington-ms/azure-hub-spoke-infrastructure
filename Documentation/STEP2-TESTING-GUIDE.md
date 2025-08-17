# Step 2 Testing Guide: Windows Admin Center Gateway VM

## 🎯 **Step 2 Objective**
Deploy a Windows Admin Center Gateway VM into the management subnet for centralized infrastructure management.

## 📋 **What This Step Implements**

### **VM Deployment**
- **VM Name**: `vm-wac-platfo-dev` (15 characters, respects Azure limit)
- **Computer Name**: `wac-platform-dev` (15 characters)
- **VM Size**: `Standard_D2s_v5` (2 vCPUs, 8GB RAM)
- **OS**: Windows Server 2022 Datacenter Azure Edition
- **Disks**: 128GB OS disk + 256GB data disk (Premium SSD)

### **Network Configuration**
- **Management Subnet**: `10.1.0.64/26` (from Step 1)
- **Private IP**: Dynamic assignment in management subnet
- **Public IP**: Static Standard SKU with FQDN
- **NSG**: Additional VM-specific security rules

### **Security Features**
- **Managed Identity**: User-assigned for Key Vault access
- **Password Storage**: Admin password stored in Key Vault
- **RDP Access**: Via Azure Bastion (secure, no direct internet RDP)
- **Firewall**: Windows Firewall configured for WAC (port 443)
- **WinRM**: Enabled for PowerShell remoting

### **Windows Admin Center**
- **Port**: 443 (HTTPS)
- **SSL Certificate**: Auto-generated during installation
- **Installation**: Automated via Custom Script Extension
- **Access Methods**: Internal (private IP) and external (public FQDN)

## 🧪 **Testing Methodology**

### **Phase 1: Pre-deployment Validation**
```bash
# Test 1: Verify Step 1 infrastructure exists
az network vnet subnet show \
  --name "snet-management-platform-ops-dev-centralus" \
  --vnet-name "vnet-hub-platform-ops-dev-centralus" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "{name:name, addressPrefix:addressPrefix}" \
  --output table

# Test 2: Verify Key Vault and Managed Identity exist
az keyvault show --name $(az keyvault list --resource-group "rg-platform-ops-dev-cen" --query "[0].name" -o tsv) --query "name" -o tsv
az identity show --name "id-platform-ops-dev-centralus" --resource-group "rg-platform-ops-dev-cen" --query "name" -o tsv
```

### **Phase 2: Template Compilation and Validation**
```bash
# Test 3: Compile Step 2 template
az bicep build --file test-step2-windows-admin-center.bicep

# Test 4: Validate template with Azure Resource Manager
az deployment group validate \
  --resource-group "rg-platform-ops-dev-cen" \
  --template-file "test-step2-windows-admin-center.bicep" \
  --parameters environment=dev workloadName=platform-ops adminPassword='YourSecurePassword123!'
```

### **Phase 3: VM Deployment**
```bash
# Test 5: Deploy Windows Admin Center VM (Step 2)
az deployment group create \
  --resource-group "rg-platform-ops-dev-cen" \
  --template-file "test-step2-windows-admin-center.bicep" \
  --parameters environment=dev workloadName=platform-ops adminPassword='YourSecurePassword123!' \
  --name "test-step2-deployment"
```

### **Phase 4: Infrastructure Verification**
```bash
# Test 6: Verify VM deployment
az vm show \
  --name "vm-wac-platfo-dev" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "{name:name, powerState:powerState, provisioningState:provisioningState, location:location}" \
  --output table

# Test 7: Check VM network configuration
az vm show \
  --name "vm-wac-platfo-dev" \
  --resource-group "rg-platform-ops-dev-cen" \
  --show-details \
  --query "{name:name, privateIps:privateIps, publicIps:publicIps, fqdns:fqdns}" \
  --output table

# Test 8: Verify VM extensions (Windows Admin Center installation)
az vm extension list \
  --vm-name "vm-wac-platfo-dev" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "[].{name:name, provisioningState:provisioningState, publisher:publisher}" \
  --output table
```

### **Phase 5: Connectivity and Access Testing**
```bash
# Test 9: Check public IP and FQDN
az network public-ip show \
  --name "pip-wac-platform-ops-dev-centralus" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "{name:name, ipAddress:ipAddress, fqdn:dnsSettings.fqdn}" \
  --output table

# Test 10: Verify NSG rules
az network nsg show \
  --name "nsg-wac-vm-platform-ops-dev-centralus" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "securityRules[].{name:name, protocol:protocol, direction:direction, access:access, priority:priority}" \
  --output table
```

### **Phase 6: Windows Admin Center Verification**
```bash
# Test 11: Check if Windows Admin Center is accessible (after VM boots)
# Note: This requires the VM to be fully started and WAC installed (5-10 minutes)

# Get the public FQDN
WAC_FQDN=$(az network public-ip show --name "pip-wac-platform-ops-dev-centralus" --resource-group "rg-platform-ops-dev-cen" --query "dnsSettings.fqdn" -o tsv)

echo "Windows Admin Center should be accessible at: https://$WAC_FQDN"
echo "Test manually: curl -k -I https://$WAC_FQDN (expect 200 or redirect)"
```

## ✅ **Success Criteria for Step 2**

### **Must Pass All Tests:**
1. **✅ Template Compilation**: Bicep template compiles without errors
2. **✅ Template Validation**: ARM validation passes
3. **✅ VM Deployment**: VM deploys successfully with "Succeeded" state
4. **✅ Network Integration**: VM gets IP in management subnet (10.1.0.64/26)
5. **✅ Public Connectivity**: Public IP and FQDN assigned
6. **✅ Extension Installation**: Custom Script Extension runs successfully
7. **✅ NSG Configuration**: VM-specific NSG rules applied
8. **✅ Key Vault Integration**: Admin password stored in Key Vault
9. **✅ Windows Admin Center**: WAC accessible on port 443
10. **✅ Bastion Access**: VM accessible via Azure Bastion

### **Expected VM Configuration:**
```json
{
  "vm": {
    "name": "vm-wac-platfo-dev",
    "computerName": "wac-platform-dev",
    "size": "Standard_D2s_v5",
    "powerState": "VM running",
    "privateIP": "10.1.0.X",
    "subnet": "snet-management-platform-ops-dev-centralus"
  },
  "access": {
    "wacUrl": "https://wac-platform-ops-dev-XXXXX.centralus.cloudapp.azure.com",
    "bastionRdp": "10.1.0.X",
    "winrmPorts": [5985, 5986]
  }
}
```

## 🔍 **Troubleshooting Guide**

### **Common Issues & Solutions**

#### **VM Name Length Issues**
- **Issue**: VM name exceeds 15 characters
- **Check**: `vm-wac-platfo-dev` = 15 characters exactly
- **Fix**: Already optimized for Azure limits

#### **Password Complexity**
```bash
# Ensure password meets Azure requirements:
# - 12-123 characters
# - Mix of uppercase, lowercase, numbers, symbols
# - Not contain username or computer name
```

#### **Extension Installation Failures**
```bash
# Check extension logs if WAC installation fails:
az vm extension show \
  --vm-name "vm-wac-platfo-dev" \
  --name "InstallWindowsAdminCenter" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "instanceView"
```

#### **Network Connectivity Issues**
```bash
# Verify management subnet NSG allows traffic:
az network nsg rule list \
  --nsg-name "nsg-management-platform-ops-dev-centralus" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "[?direction=='Inbound' && access=='Allow'].{name:name, priority:priority, ports:destinationPortRange}"
```

#### **Windows Admin Center Not Accessible**
1. **Wait Time**: WAC installation takes 5-10 minutes after VM creation
2. **Firewall**: Check Windows Firewall allows port 443
3. **Certificate**: WAC generates self-signed certificate (expect browser warning)
4. **Port**: Ensure WAC is listening on 443: `netstat -an | findstr :443`

## 🧹 **Post-Deployment Verification**

### **Manual Tests** (via Azure Bastion)
1. **RDP to VM**: Use Azure Bastion to connect to private IP
2. **WAC Service**: Check if "Windows Admin Center" service is running
3. **Firewall Rules**: Verify Windows Firewall has WAC rule (port 443)
4. **Local Access**: Test `https://localhost` from VM browser
5. **Certificate**: Verify auto-generated SSL certificate

### **Network Tests**
```bash
# Test from another VM in the VNet (if available):
# curl -k https://10.1.0.X  (replace X with actual VM IP)
# Should return HTML or redirect to login page
```

## 📊 **Step 2 Performance Metrics**

| Metric | Expected Value |
|--------|----------------|
| **VM Boot Time** | 3-5 minutes |
| **Extension Runtime** | 5-8 minutes |
| **Total Deployment** | 8-15 minutes |
| **WAC Response Time** | < 2 seconds |
| **RDP via Bastion** | < 10 seconds |

## 🚀 **Ready for Step 3**

Once Step 2 passes all tests, you'll have:

- ✅ **Fully Functional Management VM** in the management subnet
- ✅ **Windows Admin Center** accessible via HTTPS
- ✅ **Secure Access** via Azure Bastion
- ✅ **Centralized Management** capability for hub-spoke infrastructure
- ✅ **Foundation** for managing virtual machines, networking, and services

### **Next: Step 3 - Azure Static Web App**
The final step will create an Azure Static Web App with private endpoint integration for modern web application hosting.

---

**Step 2 Status**: Ready for Testing 🧪 | Next: Azure Static Web App (Step 3) 🌐
