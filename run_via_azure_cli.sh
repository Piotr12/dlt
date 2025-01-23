#!/bin/bash

# Variables
TIMESTAMP=$(date '+%Y_%m_%d_%H_%M')
RESOURCE_GROUP="VMPerformanceTestRG_${TIMESTAMP}"
LOCATION="eastus"
VM_BASE_NAME="TestVM"
IMAGE="Ubuntu2404"
ADMIN_USERNAME="azureuser"
SSH_KEY_PATH="~/.ssh/id_rsa.pub"

SIZES=("Standard_D2as_v6")
SIZES=("${SIZES[@]}" "Standard_F4als_v6")
SIZES=("${SIZES[@]}" "Standard_E4as_v5")
SIZES=("${SIZES[@]}" "Standard_D8as_v5")
SIZES=("${SIZES[@]}" "Standard_E64bs_v5")
SIZES=("${SIZES[@]}" "Standard_B4als_v2")
SIZES=("${SIZES[@]}" "Standard_D4s_v3")
SIZES=("${SIZES[@]}" "Standard_FX4mds") 
SIZES=("${SIZES[@]}" "Standard_D8als_v6")
SIZES=("${SIZES[@]}" "Standard_D4ds_v4")
SIZES=("${SIZES[@]}" "Standard_D8ds_v5")
SIZES=("${SIZES[@]}" "Standard_D8ds_v4")
SIZES=("${SIZES[@]}" "Standard_FX48mds")
SIZES=("${SIZES[@]}" "Standard_D4ds_v5")

VM_PREFIX="perf-test"
LOCAL_TEST_SCRIPT="test.py"
REMOTE_TEST_SCRIPT="/home/$ADMIN_USERNAME/test.py"
RESULTS_DIR="vm_results_${TIMESTAMP}"

# Create results directory
mkdir -p $RESULTS_DIR

# Create a resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Loop through sizes, create and test each VM
for SIZE in "${SIZES[@]}"; do
    VM_NAME="${VM_PREFIX}-${SIZE}"

    echo "Creating VM: $VM_NAME with size $SIZE..."
    az vm create \
        --resource-group $RESOURCE_GROUP \
        --name $VM_NAME \
        --image $IMAGE \
        --size $SIZE \
        --admin-username $ADMIN_USERNAME \
        --ssh-key-values $SSH_KEY_PATH \
        --output none

    echo "Copying test script to $VM_NAME..."
    # Copy the test script using base64 encoding - works on both Linux and macOS
    ENCODED_SCRIPT=$(base64 -i $LOCAL_TEST_SCRIPT | tr -d '\n')
    az vm run-command invoke \
        --resource-group $RESOURCE_GROUP \
        --name $VM_NAME \
        --command-id RunShellScript \
        --scripts "echo '$ENCODED_SCRIPT' | base64 -d > $REMOTE_TEST_SCRIPT && chmod +x $REMOTE_TEST_SCRIPT" \
        --output none

    echo "Running performance tests on $VM_NAME..."
    az vm run-command invoke \
        --resource-group $RESOURCE_GROUP \
        --name $VM_NAME \
        --command-id RunShellScript \
        --scripts "python3 $REMOTE_TEST_SCRIPT 2>&1 | tee /home/$ADMIN_USERNAME/results.csv" 
  
    # Get the public IP of the VM
    VM_IP=$(az vm show -d -g $RESOURCE_GROUP -n $VM_NAME --query publicIps -o tsv)
    
    # Download results file using scp
    echo "Downloading results from $VM_NAME..."
    scp -o StrictHostKeyChecking=no $ADMIN_USERNAME@$VM_IP:/home/$ADMIN_USERNAME/results.csv "$RESULTS_DIR/${VM_NAME}_results.csv"

    echo "Deleting VM: $VM_NAME..."
    az vm delete --resource-group $RESOURCE_GROUP --name $VM_NAME --yes --no-wait

    # sleep for 60 seconds to allow the VM to be deleted not to get quota issues
    sleep 60
done

# Clean up the resource group
echo "Deleting resource group $RESOURCE_GROUP..."
az group delete --name $RESOURCE_GROUP --yes --no-wait

echo "Performance testing completed! Results are in the $RESULTS_DIR directory"