# variables.tf

# Remote Podman host URL (e.g., ssh://user@host/path/to/podman.sock)
variable "remote_podman_host_url" {
  description = "The URL for the remote Podman host via SSH (e.g., ssh://user@host/run/user/1000/podman/podman.sock)"
  type        = string
  sensitive   = true # Mark as sensitive to prevent showing in logs
}

# Base path on the host for container data volumes
variable "data_base_path" {
  description = "The base path on the host system where container data volumes will be stored."
  type        = string
  default     = "/opt/containers" # A common default, adjust as needed
}

# PUID (User ID) for linuxserver.io containers
# This ensures file permissions inside the container match a user on the host.
variable "puid" {
  description = "The User ID (PUID) for the applications inside the linuxserver.io containers."
  type        = number
  default     = 1000 # Common default, replace with your user's PUID on cloud0
}

# PGID (Group ID) for linuxserver.io containers
# This ensures file permissions inside the container match a group on the host.
variable "pgid" {
  description = "The Group ID (PGID) for the applications inside the linuxserver.io containers."
  type        = number
  default     = 1000 # Common default, replace with your user's PGID on cloud0
}

# Timezone for all containers
variable "timezone" {
  description = "The timezone for the containers (e.g., Europe/London, America/New_York)."
  type        = string
  default     = "America/Toronto" # Default to Toronto, as per current location.
}

# MariaDB root password
variable "maria_db_root_password" {
  description = "The root password for the MariaDB database."
  type        = string
  sensitive   = true
}

# Samba username
variable "samba_username" {
  description = "The username for accessing the Samba share."
  type        = string
  sensitive   = true
}

# Samba password
variable "samba_password" {
  description = "The password for the Samba share user."
  type        = string
  sensitive   = true
}

# Network range for NFS access
variable "nfs_network" {
  description = "The network CIDR range from which NFS clients are allowed to connect (e.g., '192.168.1.0/24')."
  type        = string
  default     = "192.168.2.0/24" # Default to a common home network subnet, adjust to your actual network.
}

