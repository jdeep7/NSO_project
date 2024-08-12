#!/bin/bash

# Checking if the required arguments are present - the cloud_config, id_tag, and access_key.
# The program will not run if these arguments are not present.
: ${1:?" Please specify the cloud_config, id_tag, and access_key"}
: ${2:?" Please specify the cloud_config, id_tag, and access_key"}
: ${3:?" Please specify the cloud_config, id_tag, and access_key"}

# Capturing the current time for logging purposes
current_time=$(date)

# Assigning input arguments to variables for better readability
cloud_config_file=${1}     # Cloud configuration file (openrc file)
id_tag=${2}                # Unique identifier tag for resources
access_key=${3}            # SSH key for secure remote access

# Fetching the number of nodes from servers.conf (assuming this file exists)
server_count=$(grep -E '[0-9]' servers.conf)

# Sourcing the cloud configuration file to load environment variables (like credentials)
echo "$current_time Cleaning up $id_tag using $cloud_config_file"
source $cloud_config_file

# Define variables for OpenStack resources based on the provided id_tag
network_name="${2}_network"
subnet_name="${2}_subnet"
keypair_name="${2}_key"
router_name="${2}_router"
security_group_name="${2}_security_group"
proxy_server_name="${2}_proxy"
bastion_server_name="${2}_bastion"
dev_server_name="${2}_dev"

# Define files used for SSH configurations and IP management
ssh_config_file="config"
known_hosts_file="known_hosts"
hosts_file="hosts"
floating_ip_file="$(cat floating_ip2)"

# Retrieving the list of servers with the specified tag
server_list=$(openstack server list --name "$id_tag" -c ID -f value)
server_count=$(echo "$server_list" | wc -l)

# Deleting each server if any servers are found
if [ -n "$server_list" ]; then
  echo "$(date) We have $server_count nodes, releasing them"
  for server_id in $server_list; do
    openstack server delete $server_id
  done
  echo "$(date) Nodes are gone"
else
  echo "$(date) No nodes to release"
fi

# Deleting the keypair associated with the id_tag if it exists
keypair_list=$(openstack keypair list -f value -c Name | grep "$id_tag*")

if [ -n "$keypair_list" ]; then
  for key_name in $keypair_list; do  
    openstack keypair delete $key_name
  done
  echo "$(date) Removed $keypair_name key"
else
  echo "$(date) No keypair to delete."
fi

# Fetching and deleting all floating IPs that are currently DOWN (unassigned)
floating_ips=$(openstack floating ip list --status DOWN -f value -c "Floating IP Address")

if [ -n "$floating_ips" ]; then
  for floating_ip in $floating_ips; do
    openstack floating ip delete "$floating_ip"
  done
  echo "$(date) Removed all floating IPs"
else
  echo "$(date) No floating IPs to remove"
fi

# Fetching and deleting subnets associated with the id_tag, also removing them from the router
subnet_list=$(openstack subnet list --tag "${id_tag}" -c ID -f value)
if [ -n "${subnet_list}" ]; then
  for subnet_id in ${subnet_list}; do
    openstack router remove subnet "${router_name}" "$subnet_id"
    openstack subnet delete "$subnet_id"
  done
  echo "$(date) Removed ${subnet_name} subnet"
else
  echo "$(date) No subnets to remove"
fi

# Removing routers associated with the id_tag
router_list=$(openstack router list --tag ${id_tag} -f value -c Name)
if [ -n "$router_list" ]; then
  for router_name in $router_list; do
    openstack router delete "$router_name"
  done
  echo "$(date) Removed ${router_name} router" 
else
  echo "$(date) No routers to remove"
fi

# Removing networks associated with the id_tag
network_list=$(openstack network list --tag ${id_tag} -f value -c Name)
if [ -n "$network_list" ]; then
  for network_name in $network_list; do
    openstack network delete "$network_name"
  done
  echo "$(date) Removed ${network_name} network"
else
  echo "$(date) No networks to remove"
fi

# Removing security groups associated with the id_tag
security_group_list=$(openstack security group list --tag $id_tag -f value -c Name)
if [ -n "$security_group_list" ]; then
  for sec_group_name in $security_group_list; do
    openstack security group delete "$sec_group_name"
  done
  echo "$(date) Removed ${security_group_name} security group"
else
  echo "$(date) No security groups to remove"
fi

# Clean up temporary files created during the process

# Deleting the SSH configuration file if it exists
if [[ -f "$ssh_config_file" ]] ; then
    rm "$ssh_config_file"
fi

# Deleting the known_hosts file if it exists
if [[ -f "$known_hosts_file" ]] ; then
    rm "$known_hosts_file"
fi

# Deleting any floating_ip1 file if it exists
if [[ -f "floating_ip1" ]] ; then
    rm "floating_ip1"
fi

# Deleting any floating_ip2 file if it exists
if [[ -f "floating_ip2" ]] ; then
    rm "floating_ip2"
fi

# Deleting the hosts file if it exists
if [[ -f "$hosts_file" ]] ; then
    rm "$hosts_file"
fi
