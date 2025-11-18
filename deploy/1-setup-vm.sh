#!/bin/bash
#
# PPanel Server 虚拟机初始化脚本
# 在 GCP 虚拟机上运行此脚本，自动安装所有必需的依赖
#

set -e

echo "========================================="
echo "  PPanel Server 虚拟机环境初始化"
echo "========================================="
echo ""

# 检查是否为 root 用户
if [ "$EUID" -eq 0 ]; then 
   echo "❌ 请不要使用 root 用户运行此脚本"
   echo "   直接运行: ./deploy/1-setup-vm.sh"
   exit 1
fi

# 更新系统
echo "📦 更新系统软件包..."
sudo apt-get update
sudo apt-get upgrade -y

# 安装必要工具
echo "🔧 安装必要工具..."
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    vim \
    htop \
    wget \
    build-essential

echo ""
echo "========================================="
echo "  安装 Docker"
echo "========================================="
echo ""

# 检查 Docker 是否已安装
if command -v docker &> /dev/null; then
    echo "✅ Docker 已安装: $(docker --version)"
else
    echo "🐳 安装 Docker..."
    
    # 添加 Docker 官方 GPG 密钥
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # 设置 Docker 仓库
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 安装 Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # 将当前用户添加到 docker 组
    sudo usermod -aG docker $USER
    
    echo "✅ Docker 安装完成"
fi

# 启动 Docker 服务
echo "🚀 启动 Docker 服务..."
sudo systemctl enable docker
sudo systemctl start docker

echo ""
echo "========================================="
echo "  安装 Go"
echo "========================================="
echo ""

# 检查 Go 是否已安装
if command -v go &> /dev/null; then
    echo "✅ Go 已安装: $(go version)"
else
    echo "📦 安装 Go..."
    
    # 下载 Go（AMD64 版本）
    GO_VERSION="1.23.4"
    wget https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
    
    # 解压并安装
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
    rm go${GO_VERSION}.linux-amd64.tar.gz
    
    # 添加到 PATH
    if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        echo 'export PATH=$PATH:~/go/bin' >> ~/.bashrc
    fi
    
    # 立即生效
    export PATH=$PATH:/usr/local/go/bin
    export PATH=$PATH:~/go/bin
    
    echo "✅ Go 安装完成"
fi

echo ""
echo "========================================="
echo "  配置 Go 环境（可选）"
echo "========================================="
echo ""

# 询问是否需要配置国内镜像
read -p "是否需要配置 Go 国内镜像？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🌐 配置 Go 国内镜像..."
    go env -w GOPROXY=https://goproxy.cn,direct
    echo "✅ Go 镜像配置完成"
else
    echo "⏭️  跳过 Go 镜像配置（GCP 虚拟机通常不需要）"
fi

echo ""
echo "========================================="
echo "  配置防火墙（使用 GCP 防火墙规则）"
echo "========================================="
echo ""

# GCP 上使用防火墙规则，不需要 ufw
echo "💡 提示：GCP 虚拟机请在控制台配置防火墙规则"
echo ""
echo "需要开放的端口："
echo "  - 8080 (PPanel Server API)"
echo ""
echo "配置方法："
echo "  1. 访问: https://console.cloud.google.com/networking/firewalls/list"
echo "  2. 点击「创建防火墙规则」"
echo "  3. 配置："
echo "     名称: allow-ppanel-server"
echo "     目标: 网络中的所有实例"
echo "     来源 IPv4 范围: 0.0.0.0/0"
echo "     协议和端口: tcp:8080"
echo "  4. 点击「创建」"
echo ""

# 显示版本信息
echo "========================================="
echo "✅ 环境初始化完成！"
echo "========================================="
echo ""
echo "📦 已安装的软件："
docker --version
docker compose version
go version
echo ""
echo "📝 下一步："
echo "   1. 退出当前 SSH 会话: exit"
echo "   2. 重新连接 SSH（以使 Docker 组权限生效）"
echo "   3. 克隆代码:"
echo "      cd ~"
echo "      git clone https://github.com/perfect-panel/server.git"
echo "      cd server"
echo "   4. 运行部署脚本:"
echo "      ./scripts/deploy-from-source.sh"
echo ""
echo "💡 提示："
echo "   - Docker 组权限需要重新登录后生效"
echo "   - GCP 虚拟机网络良好，通常不需要配置 Go 镜像"
echo "   - 部署脚本会自动在 Docker 中启动 MySQL 和 Redis"
echo ""

