#url --mirrorlist="http://mirrorlist.centos.org/?release=7&arch=x86_64&repo=os"
poweroff
firewall --enabled --service=ssh
firstboot --disable
ignoredisk --only-use=vda
lang en_US.UTF-8
keyboard us
network --device eth0 --bootproto=dhcp
firewall --enabled --service=ssh
selinux --enforcing
timezone UTC --isUtc
bootloader --location=mbr --driveorder="vda" --timeout=1
rootpw --plaintext password

#repo --name="Updates" --mirrorlist="http://mirrorlist.centos.org/?release=7&arch=x86_64&repo=updates"
#repo --name="Extras" --mirrorlist="http://mirrorlist.centos.org/?release=7&arch=x86_64&repo=extras"

zerombr
clearpart --all --initlabel
part / --size=1 --grow --asprimary --fstype=ext4

%post --erroronfail
# workaround anaconda requirements and clear root password
passwd -d root
passwd -l root

# Clean up install config not applicable to deployed environments.
for f in resolv.conf fstab; do
    rm -f /etc/$f
    touch /etc/$f
    chown root:root /etc/$f
    chmod 644 /etc/$f
done

rm -f /etc/sysconfig/network-scripts/ifcfg-[^lo]*

# Set up repos for 7.6 only
mv /etc/yum.repos.d /etc/yum_repos_d.backup
mkdir /etc/yum.repos.d
chmod 0755 /etc/yum.repos.d

cat <<EOF > /etc/yum.repos.d/CentOS-Vault.repo
# C7.6.1810
[C7.6.1810-base]
name=CentOS-7.6.1810 - Base
baseurl=http://vault.centos.org/7.6.1810/os/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

[C7.6.1810-updates]
name=CentOS-7.6.1810 - Updates
baseurl=http://vault.centos.org/7.6.1810/updates/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

[C7.6.1810-extras]
name=CentOS-7.6.1810 - Extras
baseurl=http://vault.centos.org/7.6.1810/extras/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

[C7.6.1810-centosplus]
name=CentOS-7.6.1810 - CentOSPlus
baseurl=http://vault.centos.org/7.6.1810/centosplus/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0

[C7.6.1810-fasttrack]
name=CentOS-7.6.1810 - Fasttrack
baseurl=http://vault.centos.org/7.6.1810/fasttrack/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
enabled=0
EOF

sudo yum-config-manager --enable "CentOS-7.6.1810 - Base"
sudo yum-config-manager --enable "CentOS-7.6.1810 - Updates"
sudo yum-config-manager --enable "CentOS-7.6.1810 - Extras"

yum clean all

%end

%packages
@core
bash-completion
cloud-init
# cloud-init only requires python-oauthlib with MAAS. As such upstream
# has removed python-oauthlib from cloud-init's deps.
python2-oauthlib
cloud-utils-growpart
rsync
tar
yum-utils
# bridge-utils is required by cloud-init to configure networking. Without it
# installed cloud-init will try to install it itself which will not work in
# isolated environments.
bridge-utils
# Tools needed to allow custom storage to be deployed without acessing the
# Internet.
grub2-efi-x64
shim-x64
# Older versions of Curtin do not support secure boot and setup grub by
# generating grubx64.efi with grub2-efi-x64-modules.
grub2-efi-x64-modules
efibootmgr
dosfstools
lvm2
mdadm
device-mapper-multipath
iscsi-initiator-utils
-plymouth
# Remove ALSA firmware
-a*-firmware
# Remove Intel wireless firmware
-i*-firmware
%end
