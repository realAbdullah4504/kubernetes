#!/bin/bash

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

# Restart services
echo "Restarting container runtime and kubelet..."
sudo systemctl daemon-reload
sudo systemctl restart containerd.service kubelet

# Optional: Stop AppArmor if needed
echo "Disabling AppArmor..."
sudo systemctl stop apparmor && sudo systemctl disable apparmor

echo "Setup completed!"
