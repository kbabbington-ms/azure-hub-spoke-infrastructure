# Step 2 Deployment Monitoring Script

## 📊 **Current Deployment Status**

### **Deployment Information**
- **Deployment Name**: `test-step2-simple-deployment`
- **Resource Group**: `rg-platform-ops-dev-cen`
- **Template**: `test-step2-windows-admin-center-simple.bicep`
- **Status**: 🔄 **RUNNING**

### **Expected Resources**
1. **Hub VNet** (updated with management subnet)
2. **Management NSG** (network security group)
3. **VM NSG** (Windows Admin Center specific)
4. **Public IP** (for WAC external access)
5. **Network Interface** (VM connectivity)
6. **Virtual Machine** (`vm-wac-platfo-dev`)
7. **Custom Script Extension** (WAC installation)

## 🕐 **Timeline Expectations**

| Phase | Expected Duration | Status |
|-------|------------------|--------|
| **Network Resources** | 2-3 minutes | 🔄 In Progress |
| **VM Provisioning** | 3-5 minutes | ⏳ Pending |
| **OS Installation** | 2-3 minutes | ⏳ Pending |
| **Extension Execution** | 5-8 minutes | ⏳ Pending |
| **Total Deployment** | **12-19 minutes** | 🔄 **Running** |

## 🔍 **Monitoring Commands**

### **Check Deployment Status**
```bash
# Overall deployment status
az deployment group show \
  --name "test-step2-simple-deployment" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "{name:name, state:properties.provisioningState, timestamp:properties.timestamp}" \
  --output table

# Detailed deployment operations
az deployment operation group list \
  --name "test-step2-simple-deployment" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "[].{resource:properties.targetResource.resourceName, type:properties.targetResource.resourceType, state:properties.provisioningState}" \
  --output table
```

### **Check VM Status** (after VM resource appears)
```bash
# VM provisioning state
az vm show \
  --name "vm-wac-platfo-dev" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "{name:name, provisioningState:provisioningState, powerState:powerState}" \
  --output table

# VM extension status
az vm extension list \
  --vm-name "vm-wac-platfo-dev" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "[].{name:name, state:provisioningState, publisher:publisher}" \
  --output table
```

### **Check Network Resources**
```bash
# Public IP assignment
az network public-ip show \
  --name "pip-wac-platform-ops-dev-centralus" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "{name:name, ip:ipAddress, fqdn:dnsSettings.fqdn}" \
  --output table

# Network interface details
az network nic show \
  --name "nic-wac-platform-ops-dev-centralus" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "{name:name, privateIP:ipConfigurations[0].properties.privateIPAddress, subnet:ipConfigurations[0].properties.subnet.id}" \
  --output table
```

## 🚨 **Troubleshooting Guide**

### **If Deployment Fails**
```bash
# Get detailed error information
az deployment group show \
  --name "test-step2-simple-deployment" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "properties.error"

# Check specific operation failures
az deployment operation group list \
  --name "test-step2-simple-deployment" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "[?properties.provisioningState=='Failed'].{resource:properties.targetResource.resourceName, error:properties.statusMessage}"
```

### **Common Issues & Solutions**

#### **VM Size Unavailable**
- **Error**: "The requested VM size is not available"
- **Solution**: Change `vmSize` parameter to available size in Central US

#### **Subnet Full**
- **Error**: "No available IP addresses in subnet"
- **Check**: Management subnet should have 59 available IPs (10.1.0.64/26)

#### **Extension Failure**
- **Error**: Custom Script Extension fails
- **Check**: Internet connectivity and PowerShell execution policy

## ✅ **Success Indicators**

### **Deployment Complete**
- **Deployment State**: `Succeeded`
- **VM State**: `Succeeded` and `VM running`
- **Extension State**: `Succeeded`
- **Public IP**: Assigned with FQDN

### **Windows Admin Center Ready**
- **WAC URL**: `https://wac-platform-ops-dev-XXXXX.centralus.cloudapp.azure.com`
- **Port 443**: Responding with HTTPS
- **Certificate**: Self-signed SSL certificate generated
- **Service**: Windows Admin Center service running

### **Network Access**
- **Bastion RDP**: Can connect to private IP via Azure Bastion
- **Internal WAC**: `https://10.1.0.X` accessible from VNet
- **External WAC**: Public FQDN accessible from internet

---

## 📋 **Post-Deployment Checklist**

When deployment completes successfully:

- [ ] ✅ Check deployment status: `Succeeded`
- [ ] 🖥️ Verify VM is running and accessible
- [ ] 🌐 Test Windows Admin Center HTTPS access
- [ ] 🔒 Verify RDP access via Azure Bastion
- [ ] 📝 Document public FQDN and private IP
- [ ] ✅ Create Step 2 completion summary
- [ ] 🚀 Prepare for Step 3 (Static Web App)

---

**Current Status**: ⏳ Waiting for deployment completion...  
**Estimated Time Remaining**: 8-15 minutes  
**Next Action**: Monitor deployment progress and verify WAC functionality 🔍
