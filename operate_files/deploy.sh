#!/bin/bash

# VM creation function
# $1: openrc
# $2: tag
# $3: ssh_key

SECURITY_GROUP_NAME="security_$2"
NETWORK_NAME="network_$2"
KEY_NAME="$3"

create_vm() {
    local VM_NAME=$1
    
    local TAG=$2
    local KEY_NAME=$3
    
    echo "Key Name is: $KEY_NAME"
    echo "Creating VM: $VM_NAME"
    
    # Create the VM and capture its ID
    vm_id=$(openstack server create \
        --flavor "2C-2GB-20GB" \
        --image "Ubuntu 20.04 Focal Fossa x86_64" \
        --security-group $SECURITY_GROUP_NAME \
        --key-name "$KEY_NAME" \
        --network $NETWORK_NAME \
        "$VM_NAME" -f value -c id)
    
    echo "VM created with ID: $vm_id"
    
    # Wait for the VM to be active
    echo "Waiting for VM to become active..."
    while true; do
        status=$(openstack server show "$vm_id" -c status -f value)
        if [ "$status" = "ACTIVE" ]; then
            break
        fi
        sleep 20 # Wait for 30 seconds before checking again
    done
    
    # Get the VM's IP address
    vm_ip=$(openstack server show "$vm_id" -c addresses -f value | grep -oP '\d+\.\d+\.\d+\.\d+')
    
    if [ -n "$vm_ip" ]; then
        echo "Adding IP $vm_ip to ./ips file"
        echo "$vm_ip" >> ./storage/ips
    else
        echo "No IP found for the VM"
    fi
}
# Generate a 6-digit Unix time
timestamp=$(date +%s | tail -c3)

# VM name with 6-digit Unix time
VM_NAME="vm${timestamp}_$2"
create_vm "$VM_NAME" "$2" "$3"