# ####################### DNS VM #######################
module "dns" {
  source = "./modules/proxmox_vms"

  # Proxmox node name
  proxmox_target_node = var.proxmox_target_node
  disk_storage        = var.disk_storage

  # VM identification
  vm_id   = var.dns_vm_id
  vm_name = var.dns_vm_name

  # VM resources
  vm_cpu       = var.dns_cpu
  vm_memory    = var.dns_vm_memory
  vm_disk_size = var.dns_vm_disk_size

  # VM user
  vm_user          = var.dns_vm_user
  vm_user_password = var.user_password

  # Vm network
  vm_network_ip_suffix = var.dns_vm_network_ip_suffix

  # VM tags
  vm_tags = var.dns_vm_tags
}

# ####################### NFS VM #######################
module "nfs" {
  source = "./modules/proxmox_vms"

  # Proxmox node name
  proxmox_target_node = var.proxmox_target_node
  disk_storage        = var.disk_storage

  # VM identification
  vm_id   = var.nfs_vm_id
  vm_name = var.nfs_vm_name

  # VM resources
  vm_cpu       = var.nfs_cpu
  vm_memory    = var.nfs_vm_memory
  vm_disk_size = var.nfs_vm_disk_size

  # VM user
  vm_user          = var.nfs_vm_user
  vm_user_password = var.user_password

  # Vm network
  vm_network_ip_suffix = var.nfs_vm_network_ip_suffix

  # VM tags
  vm_tags = var.nfs_vm_tags
}

# ####################### K8s Master VM #######################
module "k8s_master" {

  source = "./modules/proxmox_vms"

  loop = var.k8s_master_amount

  # Proxmox node name
  proxmox_target_node = var.proxmox_target_node
  disk_storage        = var.disk_storage

  # VM identification
  vm_id   = var.k8s_master_id
  vm_name = var.k8s_master_name

  # VM resources
  vm_cpu       = var.k8s_master_cpu
  vm_memory    = var.k8s_master_memory
  vm_disk_size = var.k8s_master_disk_size

  # VM user
  vm_user          = var.k8s_master_user
  vm_user_password = var.user_password

  # Vm network
  vm_network_ip_suffix = var.k8s_master_network_ip_suffix

  # VM tags
  vm_tags = var.k8s_master_tags
}

# ####################### K8s Worker VM #######################
module "k8s_worker" {

  source = "./modules/proxmox_vms"

  loop = var.k8s_worker_amount

  # Proxmox node name
  proxmox_target_node = var.proxmox_target_node
  disk_storage        = var.disk_storage

  # VM identification
  vm_id   = var.k8s_worker_id
  vm_name = var.k8s_worker_name

  # VM resources
  vm_cpu       = var.k8s_worker_cpu
  vm_memory    = var.k8s_worker_memory
  vm_disk_size = var.k8s_worker_disk_size

  # VM user
  vm_user          = var.k8s_worker_user
  vm_user_password = var.user_password

  # Vm network
  vm_network_ip_suffix = var.k8s_worker_network_ip_suffix

  # VM tags
  vm_tags = var.k8s_worker_tags
}

# ####################### Generate 'hosts.yaml' template file #######################
module "template" {
  source = "./modules/generate_template"

  ssh_private_key_file = var.ssh_private_key_file

  nfs_ip          = module.nfs.ipv4_addresses[0]
  nfs_vm_user     = var.nfs_vm_user
  nfs_vm_password = var.user_password

  dns_ip          = module.dns.ipv4_addresses[0]
  dns_vm_user     = var.dns_vm_user
  dns_vm_password = var.user_password

  k8s_master_amount = var.k8s_master_amount
  master_user       = module.k8s_master.ciuser
  master_ips        = module.k8s_master.ipv4_addresses
  master_password   = module.k8s_master.cipassword

  k8s_worker_amount = var.k8s_worker_amount
  worker_user       = module.k8s_worker.ciuser
  worker_ips        = module.k8s_worker.ipv4_addresses
  worker_password   = module.k8s_worker.cipassword
}