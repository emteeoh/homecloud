# Cloud0 Podman Container Deployment with Terraform

This repository contains Terraform configurations to deploy various services as Podman containers on a remote NixOS server (`cloud0`).

## Services Deployed

* **Deluge:** A lightweight, free software, cross-platform BitTorrent client.
* **Samba (SMB):** For network file sharing.
* **NFS (Network File System):** Another protocol for network file sharing.
* **Jellyfin:** A free software media system.
* **MariaDB:** A community-developed, commercially supported fork of the MySQL relational database management system.

All container images are sourced from `linuxserver.io` where possible.

### Centralized Media Storage

This configuration sets up a shared media directory (`${var.data_base_path}/media` on your host) that is accessible by Jellyfin, Samba, and NFS, and where Deluge can move completed downloads.

## Prerequisites

Before you begin, ensure you have the following:

1.  **A NixOS Server (`cloud0`):** Running Podman.
2.  **SSH Access:** Your local machine needs SSH access to `cloud0` with the user you intend to use for Podman operations (e.g., `nixos@cloud0`). Ensure passwordless SSH is set up if you don't want to enter a password repeatedly.
3.  **Terraform:** Installed on your local machine.
4.  **Podman Service:** Ensure the Podman service is running and accessible via `ssh-agent` or a direct SSH connection. The `kreuzwerker/podman` Terraform provider uses SSH to connect to the remote Podman socket.

    * On `cloud0`, you might need to enable and start the Podman socket:
        ```bash
        sudo systemctl enable --now podman.socket
        ```
    * Verify it's listening:
        ```bash
        systemctl status podman.socket
        ```
5.  **Host Data Directories:** Ensure the base data path and its subdirectories for media exist on `cloud0` and have correct permissions for the user running Podman. For example:
    ```bash
    sudo mkdir -p /mnt/data/containers/media/movies
    sudo mkdir -p /mnt/data/containers/media/tvshows
    sudo mkdir -p /mnt/data/containers/deluge/{config,downloads}
    sudo mkdir -p /mnt/data/containers/samba/config
    sudo mkdir -p /mnt/data/containers/jellyfin/{config,cache}
    sudo mkdir -p /mnt/data/containers/mariadb/config
    # Set ownership to your user (e.g., 'nixos' with UID/GID 1000)
    sudo chown -R 1000:1000 /mnt/data/containers
    ```

## Setup and Deployment

Follow these steps to deploy your containers:

### 1. Clone the Repository

```bash
git clone [https://github.com/your-username/your-github-repo.git](https://github.com/your-username/your-github-repo.git)
cd your-github-repo
```

### 2. Configure Variables

Edit the `variables.tf` file or create a `terraform.tfvars` file (which is generally recommended for sensitive data and local overrides).

**Example `terraform.tfvars`:**

```terraform
# Sensitive variables (do NOT commit this file to Git!)
remote_podman_host_url = "ssh://nixos@cloud0/run/user/1000/podman/podman.sock" # Adjust user and socket path
maria_db_root_password = "YourStrongRootPassword"
samba_username         = "your_smb_user"
samba_password         = "YourSambaPassword"
nfs_network            = "192.168.1.0/24" # Your local network for NFS access

# Non-sensitive variables
data_base_path = "/mnt/data/containers" # Ensure this path exists and has correct permissions on cloud0
```

* **`remote_podman_host_url`**: This is crucial. Replace `nixos@cloud0` with your actual SSH user and hostname/IP, and ensure the `/run/user/1000/podman/podman.sock` path is correct for your user's Podman socket on NixOS. You can find your user's UID (e.g., `id -u nixos`) to get the correct path (e.g., `/run/user/YOUR_UID/podman/podman.sock`).
* **`data_base_path`**: This is the base directory on your `cloud0` server where container data will be stored. Make sure this directory exists and the user running Podman has write permissions to it.
* **`maria_db_root_password`**: Set a strong password for MariaDB's root user.
* **`samba_username`**, **`samba_password`**: Credentials for accessing the Samba share.
* **`nfs_network`**: Specify the network range from which your NFS clients will connect (e.g., your local subnet).

### 3. Initialize Terraform

```bash
terraform init
```

This command downloads the necessary Podman provider.

### 4. Review the Plan

```bash
terraform plan
```

This command shows you what Terraform will do without actually making any changes. Review the output carefully to ensure it aligns with your expectations.

### 5. Apply the Configuration

```bash
terraform apply
```

Terraform will prompt you to confirm the changes. Type `yes` and press Enter to start creating the containers.

### 6. Verify Deployment

Once `terraform apply` completes, you can check the status of your containers on `cloud0`:

```bash
ssh nixos@cloud0 "podman ps -a"
```

You should see your `deluge`, `samba`, `jellyfin`, `mariadb`, and `nfs` containers running.

### Accessing Services

* **Deluge Web UI:** `http://your_cloud0_ip:8112`
* **Samba Share:** `\\your_cloud0_ip\media` (from Windows Explorer) or `smb://your_cloud0_ip/media` (from Linux/macOS file browser). Use the `samba_username` and `samba_password` you configured.
* **NFS Share:** Mount `your_cloud0_ip:/data` on your Linux/macOS clients.
    * **Linux Example (`/etc/fstab`):** `your_cloud0_ip:/data /mnt/media nfs defaults,noatime,rw 0 0`
* **Jellyfin Web UI:** `http://your_cloud0_ip:8096`
* **MariaDB:** Access via `your_cloud0_ip:3306` using the credentials you defined.

## Post-Deployment Configuration

### Deluge - Moving Completed Downloads

After `terraform apply` and Deluge is running:

1.  Access the Deluge Web UI (`http://your_cloud0_ip:8112`).
2.  Go to **Preferences -> Downloads**.
3.  Set "Move completed to" to `/data/media`.
4.  You can then specify subfolders like `/data/media/movies` or `/data/media/tvshows` when adding torrents, or organize them manually after download. This ensures the files land directly in your shared media library.

## Managing the Deployment

* **Updating Configurations:** Modify your `.tf` files (or `terraform.tfvars`) and re-run `terraform plan` and `terraform apply`.
* **Destroying Resources:** To remove all deployed containers and associated resources managed by this Terraform configuration:
    ```bash
    terraform destroy
    ```
    **Use with caution!** This will stop and remove the containers. The data on the host (e.g., in `/mnt/data/containers`) will generally persist unless you explicitly remove those directories.

## Important Notes

* **Permissions:** Ensure the `data_base_path` and especially the `media` subdirectory on your server have appropriate read/write permissions for the user under which Podman runs the containers (typically the user that owns the Podman service, corresponding to your configured `PUID`/`PGID`).
* **Firewall:** If `cloud0` has a firewall (e.g., `firewalld` or `ufw` configured in NixOS's `configuration.nix`), you'll need to open the necessary ports to access the services from your local network:
    * **Deluge:** `8112` (TCP), `58846` (TCP/UDP)
    * **Samba:** `139` (TCP), `445` (TCP)
    * **NFS:** `2049` (TCP/UDP), `111` (TCP/UDP for rpcbind), `20048` (TCP/UDP for mountd - default for `linuxserver/nfs-ganesha`)
    * **Jellyfin:** `8096` (TCP), `8920` (TCP - HTTPS), `7359` (UDP - auto-discovery), `1900` (UDP - DLNA)
    * **MariaDB:** `3306` (TCP)
* **Security:** Always use strong, unique passwords for your services. Do not commit `terraform.tfvars` or any files containing sensitive information to your public Git repository. Use a `.gitignore` to exclude `terraform.tfvars`.

