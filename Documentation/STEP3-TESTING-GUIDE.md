# Step 3 Testing Guide: Azure Static Web App with Private Endpoint

## 🎯 **Step 3 Objective**
Deploy an Azure Static Web App with private endpoint integration for secure, modern web application hosting within the hub-spoke architecture.

## 📋 **What This Step Implements**

### **Azure Static Web App Features**
- **SKU**: Standard (supports private endpoints and custom domains)
- **Build Support**: Automatic builds from Git repository
- **Global CDN**: Azure Front Door integration
- **Custom Domains**: Support for branded domains
- **API Integration**: Serverless API functions support
- **Staging Environments**: Branch-based staging slots

### **Private Endpoint Integration**
- **Private Access**: Static Web App accessible via private IP
- **VNet Integration**: Connected to management subnet
- **Private DNS**: Custom DNS zone for private resolution
- **Network Security**: NSG rules for controlled access
- **Hybrid Access**: Both public and private endpoints available

### **Network Configuration**
- **Management Subnet**: Uses existing `10.1.0.64/26` subnet
- **Private DNS Zone**: `privatelink.azurestaticapps.net`
- **VNet Link**: Hub VNet linked to private DNS zone
- **Private IP**: Dynamic assignment in management subnet

## 🧪 **Testing Methodology**

### **Phase 1: Pre-deployment Validation**
```bash
# Test 1: Verify Step 1 & 2 infrastructure exists
az network vnet subnet show \
  --name "snet-management-platform-ops-dev-centralus" \
  --vnet-name "vnet-hub-platform-ops-dev-centralus" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "{name:name, addressPrefix:addressPrefix, availableIps:availableIps}" \
  --output table

# Test 2: Check if VM from Step 2 is running (optional dependency)
az vm show \
  --name "vm-wac-platfo-dev" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "{name:name, powerState:powerState}" \
  --output table || echo "VM not found - proceeding without it"
```

### **Phase 2: Template Compilation and Validation**
```bash
# Test 3: Compile Step 3 template
az bicep build --file test-step3-static-web-app.bicep

# Test 4: Validate template with Azure Resource Manager
az deployment group validate \
  --resource-group "rg-platform-ops-dev-cen" \
  --template-file "test-step3-static-web-app.bicep" \
  --parameters environment=dev workloadName=platform-ops
```

### **Phase 3: Static Web App Deployment**
```bash
# Test 5: Deploy Azure Static Web App (Step 3)
az deployment group create \
  --resource-group "rg-platform-ops-dev-cen" \
  --template-file "test-step3-static-web-app.bicep" \
  --parameters environment=dev workloadName=platform-ops \
  --name "test-step3-deployment"
```

### **Phase 4: Infrastructure Verification**
```bash
# Test 6: Verify Static Web App deployment
az staticwebapp list \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "[].{name:name, defaultHostname:defaultHostname, sku:sku.name, location:location}" \
  --output table

# Test 7: Check private endpoint configuration
az network private-endpoint list \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "[?contains(name, 'swa')].{name:name, privateIp:networkInterfaces[0].ipConfigurations[0].privateIPAddress, subnet:subnet.id}" \
  --output table

# Test 8: Verify private DNS zone
az network private-dns zone list \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "[].{name:name, vnetLinks:numberOfVirtualNetworkLinks}" \
  --output table
```

### **Phase 5: Connectivity and Access Testing**
```bash
# Test 9: Get Static Web App URLs
SWA_NAME=$(az staticwebapp list --resource-group "rg-platform-ops-dev-cen" --query "[0].name" -o tsv)
SWA_URL=$(az staticwebapp show --name $SWA_NAME --resource-group "rg-platform-ops-dev-cen" --query "defaultHostname" -o tsv)

echo "Public Static Web App URL: https://$SWA_URL"

# Test 10: Test public accessibility
curl -I "https://$SWA_URL" || echo "Static Web App not responding yet (may need content deployment)"

# Test 11: Get private endpoint IP
PRIVATE_IP=$(az network private-endpoint show --name "pe-swa-platform-ops-dev-centralus" --resource-group "rg-platform-ops-dev-cen" --query "networkInterfaces[0].ipConfigurations[0].privateIPAddress" -o tsv)
echo "Private Endpoint IP: $PRIVATE_IP"
```

### **Phase 6: Application Deployment** (Optional)
```bash
# Test 12: Deploy sample application (if repository provided)
# Note: This requires GitHub integration or manual upload

# Get deployment token for manual deployment
az staticwebapp secrets list \
  --name $SWA_NAME \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "properties.apiKey" \
  --output tsv
```

## ✅ **Success Criteria for Step 3**

### **Must Pass All Tests:**
1. **✅ Template Compilation**: Bicep template compiles without errors
2. **✅ Template Validation**: ARM validation passes
3. **✅ SWA Deployment**: Static Web App deploys with "Succeeded" state
4. **✅ Private Endpoint**: Private endpoint created in management subnet
5. **✅ Private DNS**: DNS zone created and linked to VNet
6. **✅ Public Access**: Default hostname accessible publicly
7. **✅ Private Access**: Private IP accessible from VNet
8. **✅ Network Integration**: Proper subnet and NSG configuration

### **Expected Configuration:**
```json
{
  "staticWebApp": {
    "name": "swa-platform-ops-dev-centralus",
    "sku": "Standard",
    "defaultHostname": "XXXXX.azurestaticapps.net",
    "status": "Ready"
  },
  "privateEndpoint": {
    "name": "pe-swa-platform-ops-dev-centralus",
    "privateIP": "10.1.0.X",
    "subnet": "snet-management-platform-ops-dev-centralus"
  },
  "privateDns": {
    "zone": "privatelink.azurestaticapps.net",
    "vnetLinked": true
  }
}
```

## 🔍 **Troubleshooting Guide**

### **Common Issues & Solutions**

#### **Static Web App SKU Issues**
- **Issue**: Standard SKU not available in region
- **Check**: Verify Static Web Apps Standard SKU availability in Central US
- **Solution**: Use `Free` SKU for testing (note: no private endpoints)

#### **Private Endpoint Creation Failures**
```bash
# Check subnet availability
az network vnet subnet show \
  --name "snet-management-platform-ops-dev-centralus" \
  --vnet-name "vnet-hub-platform-ops-dev-centralus" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "{availableIps:availableIps, used:ipConfigurations[].length(@)}"
```

#### **DNS Resolution Issues**
```bash
# Verify private DNS zone configuration
az network private-dns zone show \
  --name "privatelink.azurestaticapps.net" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "{name:name, vnetLinks:numberOfVirtualNetworkLinks}"

# Check DNS zone group
az network private-endpoint dns-zone-group list \
  --endpoint-name "pe-swa-platform-ops-dev-centralus" \
  --resource-group "rg-platform-ops-dev-cen"
```

#### **Repository Integration Issues**
- **Issue**: GitHub repository not connecting
- **Solution**: Configure GitHub integration manually after deployment
- **Alternative**: Use manual upload for testing

### **Network Access Testing**
```bash
# From Windows Admin Center VM (if Step 2 completed):
# 1. RDP via Bastion to management VM
# 2. Test private access: curl https://10.1.0.X (private IP)
# 3. Test DNS resolution: nslookup privatelink.azurestaticapps.net
```

## 📊 **Step 3 Performance Metrics**

| Metric | Expected Value |
|--------|----------------|
| **SWA Deployment** | 2-5 minutes |
| **Private Endpoint** | 1-2 minutes |
| **DNS Configuration** | 1-2 minutes |
| **Total Deployment** | 4-9 minutes |
| **First Response** | < 3 seconds |
| **Global CDN** | < 1 second (after cache) |

## 🚀 **Phase 2 Completion**

Once Step 3 passes all tests, you'll have achieved:

### **Complete Hub-Spoke Architecture**
- ✅ **Hub VNet** with Bastion and Management subnets
- ✅ **Spoke VNet** with peering and connectivity
- ✅ **Management VM** with Windows Admin Center
- ✅ **Static Web App** with private endpoint integration

### **Security Features**
- ✅ **Network Segmentation** with NSG protection
- ✅ **Private Endpoints** for secure service access
- ✅ **Azure Bastion** for secure VM access
- ✅ **Private DNS** for internal resolution

### **Modern Application Platform**
- ✅ **Centralized Management** via Windows Admin Center
- ✅ **Static Web Hosting** with global CDN
- ✅ **Hybrid Connectivity** (public + private access)
- ✅ **Scalable Architecture** ready for expansion

---

**Step 3 Status**: 🧪 Ready for Testing | **Phase 2**: Almost Complete! 🎯  
**Next Action**: Deploy and validate Azure Static Web App 🌐
