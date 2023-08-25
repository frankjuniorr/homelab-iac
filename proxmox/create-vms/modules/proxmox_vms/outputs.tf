output "ipv4_addresses" {
  value = proxmox_vm_qemu.this[*].default_ipv4_address
}

output "ciuser" {
  value = proxmox_vm_qemu.this[*].ciuser
}

output "cipassword" {
  value = proxmox_vm_qemu.this[*].cipassword
}