# vira um template por causa do 'network_ip_cidr'

####################### Variables module constants #######################
variable "on_boot" {
  description = "Determines whether the virtual machine should start automatically when the host system boots up."
  type        = bool
  default     = true
}
variable "agent" {
  description = "Specifies the number of Qemu Guest Agent instances to run in the virtual machine. The Qemu Guest Agent facilitates communication and interaction between the host and the VM."
  type        = number
  default     = 1
}
variable "bridge_network" {
  description = "The name of the bridge network interface that the virtual machine will connect to."
  type        = string
  default     = "vmbr0"
}
variable "network_ip_cidr" {
  description = "IP CIDR range"
  type        = string
  default     = "192.168.0.0/24"
}
variable "network_model" {
  description = "The network model to be used for virtual network interfaces in your infrastructure."
  type        = string
  default     = "virtio"
}
variable "disk_type" {
  description = "The type of virtual disk interface to be used for attaching disks to your virtual machines. This setting defines how the virtual machine communicates with its storage."
  type        = string
  default     = "scsi"
}
variable "vm_socket" {
  description = "The number of CPU sockets to allocate to the VM"
  type        = number
  default     = 1
}

variable "loop" {
  description = "Number of times that module runs"
  type        = number
  default     = 1
}


####################### Variables come from outside #######################
variable "proxmox_target_node" {}
variable "disk_storage" {}
variable "vm_id" {}
variable "vm_cpu" {}
variable "vm_disk_size" {}
variable "vm_name" {}
variable "vm_memory" {}
variable "vm_user" {}
variable "vm_user_password" {}
variable "vm_network_ip_suffix" {}
variable "vm_tags" {}




