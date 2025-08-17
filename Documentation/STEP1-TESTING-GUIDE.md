# Step 1 Testing Guide: Management Subnet Implementation

## 🎯 **Step 1 Objective**
Add a dedicated management subnet to the Hub VNet for Windows Admin Center Gateway VM placement.

## 📋 **What This Step Implements**

### **Network Changes**
- **Management Subnet**: `10.1.0.64/26` in Hub VNet
- **Management NSG**: Secure rules for management traffic
- **Proper Isolation**: Management subnet separate from Bastion subnet

### **Security Configuration**
- **Bastion Access**: Allow RDP/SSH from Bastion subnet (10.1.0.0/26)
- **WinRM Access**: Allow PowerShell remoting within VNet
- **Windows Admin Center**: Allow HTTPS (443) for management interface
- **Internet Access**: Allow outbound for updates and downloads
- **VNet Communication**: Allow communication within virtual network

## 🧪 **Testing Methodology**

### **Phase 1: Template Validation**
```bash
# Test 1: Compile the test template
az bicep build --file test-step1-management-subnet.bicep

# Test 2: Validate template syntax and parameters
az deployment group validate \
  --resource-group "rg-platform-ops-dev-cen" \
  --template-file "test-step1-management-subnet.bicep" \
  --parameters environment=dev workloadName=platform-ops
```

### **Phase 2: Deployment Testing**
```bash
# Test 3: Deploy the management subnet (Step 1 only)
az deployment group create \
  --resource-group "rg-platform-ops-dev-cen" \
  --template-file "test-step1-management-subnet.bicep" \
  --parameters environment=dev workloadName=platform-ops \
  --name "test-step1-deployment"
```

### **Phase 3: Infrastructure Verification**
```bash
# Test 4: Verify Hub VNet configuration
az network vnet show \
  --name "vnet-hub-platform-ops-dev-centralus" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "{name:name, addressSpace:addressSpace, subnets:subnets[].{name:name, addressPrefix:addressPrefix}}" \
  --output table

# Test 5: Verify Management Subnet exists
az network vnet subnet show \
  --name "snet-management-platform-ops-dev-centralus" \
  --vnet-name "vnet-hub-platform-ops-dev-centralus" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "{name:name, addressPrefix:addressPrefix, networkSecurityGroup:networkSecurityGroup.id}" \
  --output table

# Test 6: Verify Management NSG rules
az network nsg show \
  --name "nsg-management-platform-ops-dev-centralus" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "securityRules[].{name:name, protocol:protocol, direction:direction, priority:priority, access:access}" \
  --output table
```

### **Phase 4: Network Connectivity Testing**
```bash
# Test 7: Check subnet routing and connectivity (after deployment)
az network vnet show \
  --name "vnet-hub-platform-ops-dev-centralus" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "subnets[?contains(name, 'management')].{name:name, addressPrefix:addressPrefix, networkSecurityGroup:networkSecurityGroup}" \
  --output json

# Test 8: Verify NSG associations
az network nsg list \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "[?contains(name, 'management')].{name:name, location:location, subnets:subnets[].{name:name, addressPrefix:addressPrefix}}" \
  --output table
```

## ✅ **Success Criteria for Step 1**

### **Must Pass All Tests:**
1. **✅ Template Compilation**: `az bicep build` succeeds without errors
2. **✅ Template Validation**: `az deployment group validate` passes
3. **✅ Successful Deployment**: Template deploys without errors
4. **✅ Subnet Creation**: Management subnet exists with correct CIDR (10.1.0.64/26)
5. **✅ NSG Creation**: Management NSG exists with proper rules
6. **✅ NSG Association**: Management NSG properly associated with management subnet
7. **✅ Address Space**: Hub VNet includes both Bastion and Management subnets
8. **✅ No Conflicts**: No IP address conflicts or overlapping ranges

### **Expected Outputs:**
```json
{
  "hubVnetId": "/subscriptions/.../virtualNetworks/vnet-hub-platform-ops-dev-centralus",
  "managementSubnetId": "/subscriptions/.../subnets/snet-management-platform-ops-dev-centralus",
  "managementNsgId": "/subscriptions/.../networkSecurityGroups/nsg-management-platform-ops-dev-centralus",
  "validation": {
    "bastionSubnetExists": true,
    "managementSubnetExists": true,
    "nsgsCreated": true
  }
}
```

## 🔍 **Troubleshooting Guide**

### **Common Issues & Solutions**

#### **Template Compilation Errors**
```bash
# If compilation fails, check syntax:
az bicep build --file modules/network/hub-vnet.bicep --stdout
```

#### **Address Space Conflicts**
- **Issue**: Subnet overlap or invalid CIDR
- **Check**: Verify `10.1.0.0/26` (Bastion) and `10.1.0.64/26` (Management) don't overlap
- **Solution**: Ensure proper subnet calculation within `10.1.0.0/24`

#### **NSG Rule Conflicts**
```bash
# Check NSG rules for conflicts:
az network nsg show --name "nsg-management-platform-ops-dev-centralus" --resource-group "rg-platform-ops-dev-cen" --query "securityRules[].{name:name, priority:priority}"
```

#### **Deployment Failures**
```bash
# Get detailed deployment error:
az deployment group show \
  --name "test-step1-deployment" \
  --resource-group "rg-platform-ops-dev-cen" \
  --query "properties.error"
```

## 🧹 **Cleanup After Testing**

### **Option 1: Keep for Step 2** (Recommended)
```bash
# Leave deployed - we'll use this for Step 2 (Windows Admin Center VM)
echo "Management subnet ready for Step 2 implementation"
```

### **Option 2: Complete Cleanup**
```bash
# Only if you need to rollback completely:
az deployment group delete \
  --name "test-step1-deployment" \
  --resource-group "rg-platform-ops-dev-cen"
```

## 📋 **Step 1 Checklist**

Before proceeding to Step 2, verify:

- [ ] ✅ Template compiles without errors
- [ ] ✅ Template validation passes
- [ ] ✅ Deployment succeeds
- [ ] ✅ Hub VNet contains both Bastion and Management subnets
- [ ] ✅ Management subnet has correct CIDR (10.1.0.64/26)
- [ ] ✅ Management NSG created with appropriate rules
- [ ] ✅ NSG properly associated with management subnet
- [ ] ✅ No address space conflicts
- [ ] ✅ All outputs return expected resource IDs
- [ ] ✅ Documentation updated

## 🚀 **Ready for Step 2**

Once all tests pass, the management subnet is ready for the Windows Admin Center Gateway VM deployment in Step 2.

---

**Step 1 Status**: Ready for Testing 🧪 | Next: Windows Admin Center VM (Step 2) 🚀
