# Useful Commands

A personal reference for homelab administration tasks.

## System

### Toggle GUI

```bash
# disable GUI (boot to CLI)
sudo systemctl set-default multi-user.target && sudo reboot
```

```bash
# enable GUI (boot to desktop)
sudo systemctl set-default graphical.target && sudo reboot
```

### WiFi

```bash
# turn off
nmcli radio wifi off
```

```bash
# turn on
nmcli radio wifi on
```

---

## Storage

### External Disk — Full Setup

#### 1. Identify the disk

```bash
# list block devices
lsblk
```

```bash
# detailed disk info
sudo fdisk -l
```

#### 2. Remove existing partitions

```bash
# unmount if mounted
sudo umount /dev/sdX
```

```bash
# open fdisk for the target disk
sudo fdisk /dev/sdX
```

Inside `fdisk`:

```
d     # delete partition (repeat for all)
n     # new partition
p     # primary
1     # partition number
enter # default first sector
enter # default last sector
w     # write changes
```

#### 3. Format

```bash
# format as ext4 with a label
sudo mkfs.ext4 -L "MY-LABEL" /dev/sdX1
```

#### 4. Mount

```bash
# create mount point
sudo mkdir -p /mnt/my-label
```

```bash
# mount the partition
sudo mount /dev/sdX1 /mnt/my-label
```

Verify:

```bash
# check mounted filesystems
lsblk -f | grep sdX
```

#### 5. Auto-mount on boot

```bash
# get the UUID of the partition
sudo blkid /dev/sdX1
```

```bash
# edit fstab
sudo nano /etc/fstab
```

Add this line:

```
UUID=your-uuid-here  /mnt/my-label  ext4  defaults  0  2
```

Test:

```bash
# verify fstab entry
sudo mount -a
```

---

## Networking

```bash
# show IP addresses
ip a
```

```bash
# show routing table
ip r
```

```bash
# DNS lookup
nslookup example.com
```

```bash
# test port reachability
nc -zv 192.168.1.1 443
```

```bash
# list open ports
ss -tulpn
```

```bash
# restart networking
sudo systemctl restart NetworkManager
```

---

## Systemd Service Management

```bash
# view status
sudo systemctl status <service>
```

```bash
# start a service
sudo systemctl start <service>
```

```bash
# stop a service
sudo systemctl stop <service>
```

```bash
# restart a service
sudo systemctl restart <service>
```

```bash
# enable at boot
sudo systemctl enable <service>
```

```bash
# disable at boot
sudo systemctl disable <service>
```

```bash
# view logs
journalctl -u <service> -f
```
