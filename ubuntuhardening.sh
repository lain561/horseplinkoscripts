#!/bin/bash
# Harden Ubuntu for Horse Plinko 
# Written by Joshua Gilliland


# Define the banner file path and the message
BANNER_FILE="/etc/ssh/ssh_banner"
BANNER_MESSAGE="**********************************************
*   WARNING: Unauthorized access prohibited!   *
                                 |\    /|     
                              ___| \,,/_/     
                           ---__/ \/    \     
                          __--/     (D)  \    
                          _ -/    (_      \   
                         // /       \_ / ==\  
   __-------_____--___--/           / \_ O o) 
  /                                 /   \==/  
 /                                 /          
||          )                   \_/\          
||         /              _      /  |         
| |      /--______      ___\    /\  :         
| /   __-  - _/   ------    |  |   \ \        
 |   -  -   /                | |     \ )      
 |  |   -  |                 | )     | |      
  | |    | |                 | |    | |       
  | |    < |                 | |   |_/        
  < |    /__\                <  \             
  /__\                       /___\   
  petah...the horse is here...
  https://www.youtube.com/watch?v=Eu0AP8ZYZSM        
**********************************************"

# Create the banner file with the custom message
echo "Creating SSH banner..."
echo "$BANNER_MESSAGE" | sudo tee $BANNER_FILE > /dev/null

# Ensure that the banner is referenced in the SSH configuration file
echo "Configuring SSH to use the banner..."
sudo sed -i '/^#Banner/c\Banner /etc/ssh/ssh_banner' /etc/ssh/sshd_config

echo "SSH banner setup complete!"

# Disable root login and enforce sudo usage
echo "Disabling root login and securing SSH..."
passwd -l root
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
echo "Protocol 2" >> /etc/ssh/sshd_config
echo "AllowUsers hkeating ubuntu" >> /etc/ssh/sshd_config  # SSH whitelist
sudo systemctl restart sshd

# Install and configure the firewall (UFW)
echo "Configuring the firewall..."
sudo apt install ufw -y
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 'Apache Secure'  # 443
sudo ufw allow ftp
sudo ufw allow http
sudo ufw allow 20/tcp
sudo ufw allow 990/tcp
sudo ufw deny 4444  # Block Metasploit default port
sudo ufw enable

# Secure critical system files
echo "Securing critical system files..."
chmod 644 /etc/passwd
chown -R root:root /etc/apache2

# Remove unauthorized user accounts
echo "Removing nopasswdlogin group..."
sudo sed -i -e '/nopasswdlogin/d' /etc/group

# REPLACE "PASSWORD!"
for user in $( sed 's/:.*//' /etc/passwd);
	do
	  if [[ $( id -u $user) -ge 999 && "$user" != "nobody" ]]
	  then
		(echo "test"; echo "test") |  passwd "$user"
	  fi
done

# Secure FTP configuration (vsftpd) (may need debugging come plinko)
echo "Configuring vsftpd (FTP server)..."
sudo apt install vsftpd -y
echo "hkeating" >> /etc/vsftpd.userlist
echo "userlist_enable=YES" >> /etc/vsftpd.conf
echo "userlist_file=/etc/vsftpd.userlist" >> /etc/vsftpd.conf
echo "userlist_deny=NO" >> /etc/vsftpd.conf
echo "chroot_local_user=NO" >> /etc/vsftpd.conf
echo "anonymous_enable=NO" >> /etc/vsftpd.conf
echo "local_enable=YES" >> /etc/vsftpd.conf
echo "write_enable=YES" >> /etc/vsftpd.conf
echo "xferlog_enable=YES" >> /etc/vsftpd.conf
echo "ascii_upload_enable=NO" >> /etc/vsftpd.conf
echo "ascii_download_enable=NO" >> /etc/vsftpd.conf
sudo systemctl restart vsftpd

# Lock down the configuration files (may need debugging come plinko)
echo "Locking down critical config files..."
chattr +i /etc/vsftpd.userlist
chattr +i /etc/vsftpd.conf
chattr +i /etc/ssh/sshd_config


# Update and upgrade the system
echo "Updating and upgrading the system..."
sudo apt update && sudo apt upgrade -y
sudo apt install unattended-upgrades -y  # Enable automatic security updates

# Install security tools
echo "Installing security tools..."
apt install ranger -y
apt install fail2ban -y
apt install tmux -y
apt install curl -y
apt install whowatch -y
apt install auditd -y
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
sudo systemctl enable auditd
sudo systemctl start auditd


# Disable unnecessary services
echo "Disabling unnecessary daemons..."
sudo systemctl disable cups
sudo systemctl disable avahi-daemon
sudo systemctl disable bluetooth
sudo systemctl stop cups
sudo systemctl stop avahi-daemon
sudo systemctl stop bluetooth

# Enable AppArmor
echo "Enabling AppArmor..."
sudo systemctl enable apparmor
sudo systemctl start apparmor

# Disable IPv6 (if not needed)
echo "Disabling IPv6..."
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p

# Run Lynis 
echo "Running Lynis security audit..."
sudo apt install lynis -y
sudo lynis audit system

# Backup necessary files (for scoring purposes, edit based on what files are used during comp)


# Final check
pwck

echo "Ubuntu system hardening completed!"
