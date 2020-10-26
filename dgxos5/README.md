
> https://discourse.maas.io/t/creating-a-custom-ubuntu-image/1652

```sh
sudo mount /work/DGXOS-5.0.0-2020-10-01-18-07-44.iso /mnt/dgxiso-5.0

mkdir /work/dgxos-5
cd /work/dgxos-5
unsquashfs /mnt/dgxiso-5.0/live/filesystem.squashfs

mkdir /tmp/work
cd /tmp/work
sudo tar xf /work/dgxos-5/squashfs-root/curtin/ubuntu-20.04-server-cloudimg-amd64-root.tar.xz

sudo mount -o bind /proc /tmp/work/proc
sudo mount -o bind /dev /tmp/work/dev
sudo mount -o bind /sys /tmp/work/sys
sudo mv /tmp/work/etc/resolv.conf /tmp/work/etc/resolv.conf.bak
sudo cp /etc/resolv.conf /tmp/work/etc/
sudo chroot /tmp/work /bin/bash
```

missing dpkg in dgx os root fs (exists in focal current img):
  python3-pexpect
  python3-ptyprocess

Existing MAAS/DGX-2 stuff:

  docs: https://dgxdownloads.nvidia.com/custhelp/dgx2/Knowledgebase/DGX-MAAS-Setup-Guide.pdf
  curtin file: https://dgxdownloads.nvidia.com/custhelp/dgx2/Knowledgebase/curtin-dgx-19.07.1


Steps:
* download ISO to MAAS machine and mount
* unsquash root image
* run nginx container serving up squash fs contents
* during deployment, curtin file pulls down squash fs contents to target machine
* curtin file runs 'preseed.sh', etc. to do DGX-specific install

Host setup:
```sh
cd /work/dgxos-5/squashfs-root
#docker run -it --rm -d -p 8080:80 --name web -v ${PWD}:/usr/share/nginx/html nginx
docker run -it --rm -d -p 8080:80 --name web -v ${PWD}:/usr/share/nginx/html jorgeandrada/nginx-autoindex
```

Curtin script:
```sh
# remote machine as root:
wget -P /curtin -nd -nH -r --no-parent maas.lab:8080/curtin/
wget -P /usr/local/sbin/nv_scripts -nd -nH -r --no-parent maas.lab:8080/usr/local/sbin/nv_scripts/
wget -o /bin/live-medium-eject maas.lab:8080/bin/live-medium-eject

sudo chmod +x /usr/local/sbin/nv_scripts/*
sudo chmod +x /bin/live-medium-eject

cd /curtin
sed -i 's_$(cat /proc/cmdline)_"$@"_g' preseed.sh
sed -i 's/parse_cmdline$/parse_cmdline "$@"/g' preseed.sh
bash ./preseed.sh # dgx force-platform=dgx1 force-curtin=${PWD}/dgx1-curtin.yaml
```


----------------------------------------------

```sh
# install dependencies (Ubuntu 18.04)
sudo apt -y install qemu qemu-utils

# install packer
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install packer

# go to packer template directory for DGX OS 5, i.e
cd packer-maas/dgxos5

# download DGX OS somewhere (i.e. /work)
# generate checksum of image
sha256sum /work/DGXOS-5.0.0-2020-10-01-18-07-44.iso
# pass variables to `build` command,
# or edit dgxos5.json file with ISO location and SHA sum (dgxos5_iso and dgxos5_sha256sum)
# i.e.
#    "variables":
#        {
#            "dgxos5_iso": "/work/DGXOS-5.0.0-2020-10-01-18-07-44.iso",
#            "dgxos5_sha256sum": "6e5c7ba2024640b3f23ec8681c15c8ccf8997a23da91c7e9d4eacf73bb564bee"
#        },

# build image
sudo PACKER_LOG=1 packer build dgxos5.json
# optionally, instead of modifying config file:
sudo PACKER_LOG=1 packer build -var 'dgxos5_iso=/path/to/dgx_iso' -var 'dgxos5_sha256sum=<dgx_os_iso_sha256_sum>' dgxos5.json

## debug stuff
# to manually test qemu steps for debug purposes:
mkdir ~/output-qemu
qemu-img create -f qcow2 output-qemu/packer-qemu 9G
qemu-img convert -O qcow2 output-qemu/packer-qemu output-qemu/packer-qemu.convert
/usr/bin/qemu-system-x86_64 -name packer-qemu -boot once=d -drive file=~/output-qemu/packer-qemu,if=virtio,cache=writeback,discard=ignore,format=qcow2 -drive file=/work/DGXOS-5.0.0-2020-10-01-18-07-44.iso,index=0,media=cdrom -serial stdio -m 20
48M -vnc 0.0.0.0:81 -machine type=pc,accel=tcg -netdev user,id=user.0 -device virtio-net,netdev=user.0
# connect to VNC on: <machine>:5981 (no password)

# if you're connected to the VNC console, you can ctrl-alt-F2 to get another TTY, log in with the user 'root' and no password
# ubuntu kernel cmd args/boot params:
#  https://manpages.ubuntu.com/manpages/focal/en/man7/kernel-command-line.7.html
#  https://manpages.ubuntu.com/manpages/focal/en/man7/bootparam.7.html
#  https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html
```

```sh
# tmp stuff
"force-curtin=http://{{ .HTTPIP }}:{{ .HTTPPort }}/curtin.yaml ",
"force-platform=dgx-vbox ",
                "offwhendone ",
            # newer dgx os 5 image:
            "dgxos5_iso": "/scratch/DGXOS-5.0.0-2020-10-23-18-34-11.iso",
            "dgxos5_sha256sum": "2eefe51fea356642cbe087db6bac802179db6290db2fc192e81a4ed67b5ee30b"
            # regular dgx os 5 image:
            "dgxos5_iso": "/scratch/DGXOS-5.0.0-2020-10-01-18-07-44.iso",
            "dgxos5_sha256sum": "6e5c7ba2024640b3f23ec8681c15c8ccf8997a23da91c7e9d4eacf73bb564bee"
            # egx test image: ( has different grub menu entries)
            "dgxos5_iso": "/scratch/egxtest-5.0.0-2020-10-23-14-40-24.iso",
            "dgxos5_sha256sum": "d7de20b8922fc7c3cf319afebe1a1b51a96f6af3989f12149445831e39098649"

# foo
using preseed, get on console, stop sshd service, run: dhclient ens3
```
