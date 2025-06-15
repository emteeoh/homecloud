# outputs.tf

# Output the names and status of the deployed containers
output "deluge_container_status" {
  description = "Status of the Deluge container."
  value       = "Name: ${podman_container.deluge.name}, Status: ${podman_container.deluge.state}"
}

output "samba_container_status" {
  description = "Status of the Samba container."
  value       = "Name: ${podman_container.samba.name}, Status: ${podman_container.samba.state}"
}

output "nfs_container_status" {
  description = "Status of the NFS container."
  value       = "Name: ${podman_container.nfs.name}, Status: ${podman_container.nfs.state}"
}

output "jellyfin_container_status" {
  description = "Status of the Jellyfin container."
  value       = "Name: ${podman_container.jellyfin.name}, Status: ${podman_container.jellyfin.state}"
}

output "mariadb_container_status" {
  description = "Status of the MariaDB container."
  value       = "Name: ${podman_container.mariadb.name}, Status: ${podman_container.mariadb.state}"
}

# Output the host ports for accessing services
output "deluge_web_port" {
  description = "Host port for Deluge Web UI."
  value       = podman_container.deluge.ports[0].host_port # Assuming the first port is 8112
}

output "jellyfin_web_port" {
  description = "Host port for Jellyfin Web UI."
  value       = podman_container.jellyfin.ports[0].host_port # Assuming the first port is 8096
}

output "mariadb_port" {
  description = "Host port for MariaDB database."
  value       = podman_container.mariadb.ports[0].host_port # Assuming the first port is 3306
}

output "samba_ports" {
  description = "Host ports for Samba (SMB)."
  value       = [for port in podman_container.samba.ports : port.host_port]
}

output "nfs_ports" {
  description = "Host ports for NFS."
  value       = [for port in podman_container.nfs.ports : port.host_port]
}
