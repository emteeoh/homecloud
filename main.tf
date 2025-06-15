# main.tf

# Define the Terraform version constraint
terraform {
  required_providers {
    # Specify the Podman provider and its version
    podman = {
      source  = "kreuzwerker/podman"
      version = "~> 1.0"
    }
  }
}

# Configure the Podman provider to connect to the remote Podman socket via SSH
# The host URL is taken from a variable, allowing for flexible configuration.
provider "podman" {
  host = var.remote_podman_host_url
}

# --- Container Definitions ---

# 1. Deluge Container
# A BitTorrent client with a web UI.
resource "podman_container" "deluge" {
  name  = "deluge"
  image = "lscr.io/linuxserver/deluge:latest" # Using linuxserver.io image

  # Environment variables for user ID, group ID, and timezone
  env = {
    PUID = var.puid # User ID for the container process
    PGID = var.pgid # Group ID for the container process
    TZ   = var.timezone # Timezone for the container
  }

  # Port mappings: HostPort:ContainerPort
  # Web UI on port 8112, Daemon port on 58846 (TCP/UDP)
  ports = [
    { host_port = 8112, container_port = 8112 },
    { host_port = 58846, container_port = 58846, protocol = "tcp" },
    { host_port = 58846, container_port = 58846, protocol = "udp" },
  ]

  # Volume mounts: HostPath:ContainerPath
  # Configuration files, temporary downloads, and access to the shared media directory
  volumes = [
    { host_path = "${var.data_base_path}/deluge/config", container_path = "/config" },
    { host_path = "${var.data_base_path}/deluge/downloads", container_path = "/downloads" }, # Temporary downloads
    { host_path = "${var.data_base_path}/media", container_path = "/data/media" }, # Access to shared media
  ]

  # Restart policy: Always try to restart if it stops
  restart_policy = "unless-stopped"
}

# 2. Samba (SMB) Container
# Provides network file sharing for your local network.
resource "podman_container" "samba" {
  name  = "samba"
  image = "lscr.io/linuxserver/samba:latest" # Using linuxserver.io image

  # Environment variables for user ID, group ID, timezone, and Samba user/password
  env = {
    PUID          = var.puid
    PGID          = var.pgid
    TZ            = var.timezone
    USER          = var.samba_username # Samba username
    PASSWORD      = var.samba_password # Samba password
    # SHARE_NAME and SHARE_PATH are often auto-configured by the image
    # based on the mounted volume if it's the only one at /share
    # For more complex setups, you might add specific SHARE_NAME and SHARE_PATH here.
  }

  # Port mappings for SMB protocol (NetBIOS and SMB)
  ports = [
    { host_port = 139, container_port = 139 }, # NetBIOS Session Service
    { host_port = 445, container_port = 445 }, # SMB over TCP/IP
  ]

  # Volume mounts for configuration and the shared data (central media directory)
  volumes = [
    { host_path = "${var.data_base_path}/samba/config", container_path = "/config" },
    { host_path = "${var.data_base_path}/media", container_path = "/share" }, # This is the central media directory that will be shared as "share" by default
  ]

  restart_policy = "unless-stopped"
}

# 3. NFS-Ganesha Container (for Network File System sharing)
# Provides NFS file sharing for your local network, allowing Linux/macOS clients to mount the media.
resource "podman_container" "nfs" {
  name  = "nfs"
  image = "lscr.io/linuxserver/nfs-ganesha:latest" # Using linuxserver.io image

  # Environment variables for user ID, group ID, timezone, and network settings
  env = {
    PUID          = var.puid
    PGID          = var.pgid
    TZ            = var.timezone
    # The NFS_EXPORT_0 variable defines the NFS share:
    # /data: The path inside the container that is exported.
    # ${var.nfs_network}(rw,sync,no_subtree_check,insecure): Export options.
    #   - rw: Read/write access
    #   - sync: Synchronous writes (safer, but can be slower)
    #   - no_subtree_check: Prevents issues with subdirectories when parent directory is exported
    #   - insecure: Allows connections from non-privileged ports (common for home labs)
    NFS_EXPORT_0  = "/data ${var.nfs_network}(rw,sync,no_subtree_check,insecure)"
    RPC_BIND_PORT = 111 # Standard RPCBind port
    MOUNTD_PORT   = 20048 # Standard MountD port for this image
  }

  # Port mappings for NFS. Note that NFS typically uses dynamic ports beyond 2049,
  # but this image fixes RPCBind and MountD ports for easier firewall configuration.
  ports = [
    { host_port = 2049, container_port = 2049, protocol = "tcp" }, # NFS
    { host_port = 2049, container_port = 2049, protocol = "udp" }, # NFS (often UDP for efficiency)
    { host_port = 111, container_port = 111, protocol = "tcp" },   # RPCBind
    { host_port = 111, container_port = 111, protocol = "udp" },   # RPCBind
    { host_port = 20048, container_port = 20048, protocol = "tcp" }, # MountD
    { host_port = 20048, container_port = 20048, protocol = "udp" }, # MountD
  ]

  # Volume mount for the shared media directory
  volumes = [
    { host_path = "${var.data_base_path}/media", container_path = "/data" }, # Central media directory as the NFS export
  ]

  restart_policy = "unless-stopped"
}

# 4. Jellyfin Container
# A free software media system, offering media organization and streaming.
resource "podman_container" "jellyfin" {
  name  = "jellyfin"
  image = "lscr.io/linuxserver/jellyfin:latest" # Using linuxserver.io image

  # Environment variables for user ID, group ID, and timezone
  env = {
    PUID = var.puid
    PGID = var.pgid
    TZ   = var.timezone
  }

  # Port mappings: Web UI on 8096, various other optional ports for discovery/streaming
  ports = [
    { host_port = 8096, container_port = 8096 }, # Main web UI
    { host_port = 8920, container_port = 8920, protocol = "tcp" }, # HTTPS (if enabled in Jellyfin)
    { host_port = 7359, container_port = 7359, protocol = "udp" }, # Auto-discovery
    { host_port = 1900, container_port = 1900, protocol = "udp" }, # DLNA
  ]

  # Volume mounts for configuration, cache, and media libraries
  # These point directly to subdirectories within the central media path
  volumes = [
    { host_path = "${var.data_base_path}/jellyfin/config", container_path = "/config" },
    { host_path = "${var.data_base_path}/jellyfin/cache", container_path = "/cache" },
    { host_path = "${var.data_base_path}/media/movies", container_path = "/data/movies", read_only = true }, # Media access (read-only for Jellyfin)
    { host_path = "${var.data_base_path}/media/tvshows", container_path = "/data/tvshows", read_only = true }, # Media access (read-only for Jellyfin)
    # Add more media library mounts as needed, ensuring they are subdirs of /mnt/data/containers/media
  ]

  restart_policy = "unless-stopped"
}

# 5. MariaDB Container
# A robust, scalable relational database server.
resource "podman_container" "mariadb" {
  name  = "mariadb"
  image = "lscr.io/linuxserver/mariadb:latest" # Using linuxserver.io image

  # Environment variables for user ID, group ID, timezone, and MariaDB root password
  env = {
    PUID                 = var.puid
    PGID                 = var.pgid
    TZ                   = var.timezone
    MYSQL_ROOT_PASSWORD  = var.maria_db_root_password # Root password for MariaDB
    # Optionally, to create a specific user/database on first run:
    # MYSQL_DATABASE     = "my_database"
    # MYSQL_USER         = "my_user"
    # MYSQL_PASSWORD     = "my_password"
  }

  # Port mapping for MariaDB (standard MySQL port)
  ports = [
    { host_port = 3306, container_port = 3306 },
  ]

  # Volume mount for MariaDB data persistence
  volumes = [
    { host_path = "${var.data_base_path}/mariadb/config", container_path = "/config" },
  ]

  restart_policy = "unless-stopped"
}

