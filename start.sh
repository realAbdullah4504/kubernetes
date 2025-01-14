#!/bin/bash

# sudo cat /var/log/cloud-init-output.log
# sudo cat /var/log/cloud-init.log

set -e
# Update system packages
echo "Updating system packages..."
sudo apt-get update

# Install Docker if not installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    sudo apt-get install -y docker.io
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker ubuntu
    newgrp docker
fi

# Install Kubernetes tools if not installed
if ! command -v kubeadm &> /dev/null; then
    echo "Installing Kubernetes tools..."
    sudo apt-get install -y apt-transport-https ca-certificates curl gpg
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
fi


# swap of
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

cat <<EOF | sudo tee /etc/modules-load.d/k8
overlay
br_netfilter
EOF

sudo modprobe overlay

sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

cat <<EOF | sudo tee /etc/docker/daemon.json
 {
   "exec-opts": ["native.cgroupdriver=systemd"],
   "log-driver": "json-file",
   "log-opts": {
   "max-size": "100m"
},
"storage-driver": "overlay2"
}
EOF

cat <<EOF | sudo tee /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
Environment="KUBELET_EXTRA_ARGS=--fail-swap-on=false"
EOF

# Apply sysctl params without reboot
sudo sysctl --system

cat <<EOF | sudo tee /etc/default/kubelet
KUBELET_EXTRA_ARGS="--cgroup-driver=cgroupfs"
EOF

# Optional: Stop AppArmor if needed
echo "Disabling AppArmor..."
sudo systemctl stop apparmor && sudo systemctl disable apparmor

# Restart services
echo "Restarting container runtime and kubelet..."
sudo systemctl daemon-reload
sudo systemctl restart containerd.service kubelet

# Initialize Kubernetes cluster
echo "Initializing Kubernetes cluster..."
sudo apt install kubectx

# Add kubectl alias to .bashrc
echo "alias k='kubectl'" >> /home/ubuntu/.bashrc
echo "export EDITOR=nano" >> /home/ubuntu/.bashrc

# Reload .bashrc
source /home/ubuntu/.bashrc

echo "Setup completed!"
