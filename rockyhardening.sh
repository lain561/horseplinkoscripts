#!/bin/bash
# Harden Rocky Linux for Horse Plinko
# Written by Joshua Gilliland

# Update and upgrade 
echo "Updating and upgrading the system..."
sudo dnf update -y
sudo dnf install epel-release -y  # Enable Extra Packages for Enterprise Linux (EPEL)

# Security Upgrades
echo "Installing security updates..."
sudo dnf install dnf-automatic -y
sudo systemctl enable --now dnf-automatic.timer


# Disable root login and force sudo usage
echo "Disabling root login and securing SSH..."
passwd -l root
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
echo "Protocol 2" >> /etc/ssh/sshd_config
echo "AllowUsers hkeating rockyuser" >> /etc/ssh/sshd_config  # SSH whitelist
sudo systemctl restart sshd

#  Firewall (firewalld)
echo "Configuring the firewall..."
sudo dnf install firewalld -y
sudo systemctl enable --now firewalld
sudo firewall-cmd --set-default-zone=public
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=ftp
sudo firewall-cmd --permanent --add-port=20/tcp
sudo firewall-cmd --permanent --add-port=990/tcp
sudo firewall-cmd --permanent --remove-port=4444/tcp  # Block Metasploit default port (noobs lol)
sudo firewall-cmd --reload

# Secure important system files
echo "Securing critical system files..."
chmod 644 /etc/passwd
chown -R root:root /etc/httpd

# Remove unauthorized user accounts
echo "Removing unauthorized groups and users..."
sudo sed -i -e '/nopasswdlogin/d' /etc/group

default_users=("hkeating" "rockyuser")
for user in "${default_users[@]}"; do
  echo "Checking password for $user..."
  passwd_expiry=$(sudo chage -l $user | grep "Password expires" | cut -d: -f2)

  if [[ $passwd_expiry == " never" ]]; then
    echo "User $user has a default or non-expiring password, forcing password change."
    sudo passwd $user
  else
    echo "Password for $user is already set with an expiration policy."
  fi
done

# Secure FTP configuration (vsftpd) (may need debugging come plinko)
echo "Configuring vsftpd (FTP server)..."
sudo dnf install vsftpd -y
echo "hkeating" >> /etc/vsftpd/user_list
echo "userlist_enable=YES" >> /etc/vsftpd/vsftpd.conf
echo "userlist_file=/etc/vsftpd/user_list" >> /etc/vsftpd/vsftpd.conf
echo "userlist_deny=NO" >> /etc/vsftpd/vsftpd.conf
echo "chroot_local_user=NO" >> /etc/vsftpd/vsftpd.conf
echo "anonymous_enable=NO" >> /etc/vsftpd/vsftpd.conf
echo "local_enable=YES" >> /etc/vsftpd/vsftpd.conf
echo "write_enable=YES" >> /etc/vsftpd/vsftpd.conf
echo "xferlog_enable=YES" >> /etc/vsftpd/vsftpd.conf
echo "ascii_upload_enable=NO" >> /etc/vsftpd/vsftpd.conf
echo "ascii_download_enable=NO" >> /etc/vsftpd/vsftpd.conf
sudo systemctl restart vsftpd

# Lock down the configuration files (may need debugging come plinko)
echo "Locking down critical config files..."
chattr +i /etc/vsftpd/user_list
chattr +i /etc/vsftpd/vsftpd.conf
chattr +i /etc/ssh/sshd_config

# Install security tools
echo "Installing security tools..."
sudo dnf install fail2ban tmux curl audit -y
sudo systemctl enable --now fail2ban
sudo systemctl enable --now auditd


# Disable needless services
echo "Disabling unnecessary daemons..."
sudo systemctl disable cups
sudo systemctl disable avahi-daemon
sudo systemctl disable bluetooth
sudo systemctl stop cups
sudo systemctl stop avahi-daemon
sudo systemctl stop bluetooth

# Enable SELinux 
echo "Enabling SELinux..."
sudo setenforce 1
sudo sed -i 's/SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config

# Disable IPv6 (if not needed)
echo "Disabling IPv6..."
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p

# Run Lynis
echo "Running Lynis security audit..."
sudo dnf install lynis -y
sudo lynis audit system

# Backup necessary files (for scoring purposes, edit based on what files are used during comp)


# Final check
pwck

echo "Rocky Linux system hardening completed!"
