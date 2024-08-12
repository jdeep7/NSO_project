#!/bin/bash

# Checking if the required arguments are present - the openrc file, the tag, and the ssh_key
# The script will exit if any of these arguments are missing.
: ${1:?" Please specify the openrc file, tag, and ssh_key"}
: ${2:?" Please specify the openrc file, tag, and ssh_key"}
: ${3:?" Please specify the openrc file, tag, and ssh_key"}

current_time=$(date)
openrc_file=${1}     # OpenRC access file path
tag=${2}             # Identifier tag for resources
ssh_key_file=${3}    # Path to the SSH key file
server_count=$(grep -E '[0-9]' servers.conf) # Read the server count from a configuration file

# Source the OpenRC file to set environment variables for OpenStack CLI
echo "$current_time Starting cleanup for $tag using $openrc_file"
source $openrc_file

# Define resource names based on the provided tag
network_name="${2}_net"
subnet_name="${2}_subnet"
keypair_name="${2}_keypair"
router_name="${2}_router"
security_group_name="${2}_secgroup"
proxy_server="${2}_proxy"
bastion_server="${2}_bastion"
dev_server="${2}_server"

# Define file paths for SSH and floating IP configurations
ssh_config="config"
known_hosts="known_hosts"
hosts_list="hosts"
floating_ip_file="floating_ip2"

# Retrieve a list of servers with the specified tag and delete them
server_list=$(openstack server list --name "$tag" -c ID -f value)
server_count=$(echo "$server_list" | wc -l)

# Deleting each server based on the retrieved list
if [ -n "$server_list" ]; then
  echo "$(date) Found $server_count nodes, deleting them"
  for server_id in $server_list; do
    openstack server delete $server_id
  done
  echo "$(date) All nodes have been deleted"
else
  echo "$(date) No nodes found for deletion"
fi

# Retrieve and delete the keypairs associated with the specified tag
keypair_list=$(openstack keypair list -f value -c Name | grep "$tag*")

if [ -n "$keypair_list" ]; then
  for key in $keypair_list; do  
    openstack keypair delete $key
  done
  echo "$(date) Deleted keypair $keypair_name"
else
  echo "$(date) No keypair found for deletion"
fi

# Retrieve and remove any unused floating IPs
floating_ips=$(openstack floating ip list --status DOWN -f value -c "Floating IP Address")

if [ -n "$floating_ips" ]; then
  for ip in $floating_ips; do
    openstack floating ip delete "$ip"
  done
  echo "$(date) All floating IPs removed"
else
  echo "$(date) No floating IPs to remove"
fi

# Remove subnets associated with the specified tag and detach them from the router
subnet_ids=$(openstack subnet list --tag "$tag" -c ID -f value)
if [ -n "$subnet_ids" ]; then
  for subnet_id in $subnet_ids; do
    openstack router remove subnet "$router_name" "$subnet_id"
    openstack subnet delete "$subnet_id"
  done
  echo "$(date) Removed subnets tagged with $tag"
else
  echo "$(date) No subnets found for removal"
fi

# Remove routers associated with the specified tag
router_list=$(openstack router list --tag "$tag" -f value -c Name)
if [ -n "$router_list" ]; then
  for router in $router_list; do
    openstack router delete "$router"
  done
  echo "$(date) Removed routers tagged with $tag"
else
  echo "$(date) No routers found for removal"
fi

# Remove networks associated with the specified tag
network_list=$(openstack network list --tag "$tag" -f value -c Name)
if [ -n "$network_list" ]; then
  for network in $network_list; do
    openstack network delete "$network"
  done
  echo "$(date) Removed networks tagged with $tag"
else
  echo "$(date) No networks found for removal"
fi

# Remove security groups associated with the specified tag
security_group_list=$(openstack security group list --tag "$tag" -f value -c Name)
if [ -n "$security_group_list" ]; then
  for sg in $security_group_list; do
    openstack security group delete "$sg"
  done
  echo "$(date) Removed security groups tagged with $tag"
else
  echo "$(date) No security groups found for removal"
fi

# Clean up local configuration files
if [[ -f "$ssh_config" ]]; then
    rm "$ssh_config"
fi

if [[ -f "$known_hosts" ]]; then
    rm "$known_hosts"
fi

if [[ -f "$floating_ip_file" ]]; then
    rm "$floating_ip_file"
fi

if [[ -f "$hosts_list" ]]; then
    rm "$hosts_list"
fi
