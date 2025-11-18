#!/bin/bash
#
# 在虚拟机上从源代码构建并部署
# 这个脚本会：
# 1. 拉取最新代码
# 2. 编译 Go 应用
# 3. 构建 Docker 镜像
# 4. 启动容器（MySQL + Redis + Server）
#

set -e

VM_IP="34.177.90.11"

echo "========================================="
echo "  PPanel Server 从源代码构建并部署"
echo "========================================="
echo ""

# 检查是否在项目根目录
if [ ! -f "go.mod" ]; then
    echo "❌ 请在项目根目录运行此脚本"
    exit 1
fi

PROJECT_ROOT=$(pwd)

# 检查并安装 Docker
if ! docker info > /dev/null 2>&1; then
    echo "📦 Docker 未安装，正在安装..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo "✓ Docker 安装完成"
    echo "⚠️  请退出并重新登录以使 Docker 组权限生效，然后重新运行此脚本"
    exit 0
fi

echo "✓ Docker 已安装"

# 检查并安装 Go
if ! command -v go &> /dev/null; then
    echo "📦 Go 未安装，正在安装..."
    sudo apt update
    sudo apt install -y golang-go
    
    # 验证安装
    if ! command -v go &> /dev/null; then
        echo "❌ Go 安装失败，请手动安装"
        exit 1
    fi
    echo "✓ Go 安装完成"
fi

echo "✓ Go 版本: $(go version)"
echo ""

# 如果是 Git 仓库，拉取最新代码
if [ -d ".git" ]; then
    echo "🔄 拉取最新代码..."
    git pull || echo "警告：git pull 失败，继续使用本地代码"
    echo ""
fi

echo "========================================="
echo "第一步：构建 Go 应用"
echo "========================================="
echo ""

# 清理旧的构建产物
echo "🧹 清理旧的构建产物..."
rm -rf bin/ppanel-server 2>/dev/null || true

# 下载依赖
echo "📦 下载 Go 依赖..."
go mod download

# 构建应用
echo "🔨 构建 Go 应用..."
VERSION=$(git describe --tags 2>/dev/null || echo "v1.1.10")
BUILD_TIME=$(date -u +"%a %b %d %H:%M:%S %Z %Y")

CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
  -trimpath \
  -ldflags "-X 'github.com/perfect-panel/server/pkg/constant.Version=${VERSION}' -X 'github.com/perfect-panel/server/pkg/constant.BuildTime=${BUILD_TIME}' -w -s" \
  -o bin/ppanel-server \
  ppanel.go

# 检查构建产物
if [ ! -f "bin/ppanel-server" ]; then
    echo "❌ 构建失败：缺少可执行文件"
    exit 1
fi

echo "✓ 应用构建成功"
echo ""

echo "========================================="
echo "第二步：构建 Docker 镜像"
echo "========================================="
echo ""

# 构建 Server 镜像
echo "🐳 构建 Server 镜像..."
docker build \
  --build-arg VERSION=${VERSION} \
  -t ppanel-server:local \
  -f Dockerfile \
  .

echo "✓ Docker 镜像构建成功"
echo ""

echo "========================================="
echo "第三步：部署应用"
echo "========================================="
echo ""

# 创建 docker-compose 配置
cat > /tmp/docker-compose-server.yml << 'EOF'
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: ppanel-mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: ppanel_root_password
      MYSQL_DATABASE: ppanel
      MYSQL_USER: ppanel
      MYSQL_PASSWORD: ppanel_password
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    command: --default-authentication-plugin=mysql_native_password
    networks:
      - ppanel-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      timeout: 5s
      retries: 10
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  redis:
    image: redis:7.0
    container_name: ppanel-redis
    restart: always
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes
    networks:
      - ppanel-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      timeout: 5s
      retries: 10
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  server:
    image: ppanel-server:local
    container_name: ppanel-server
    restart: always
    ports:
      - "8080:8080"
    environment:
      - PPANEL_DB=ppanel:ppanel_password@tcp(mysql:3306)/ppanel
      - PPANEL_REDIS=redis://redis:6379
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - ppanel-network
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  mysql_data:
  redis_data:

networks:
  ppanel-network:
    name: ppanel-network
EOF

# 停止旧容器
echo "🛑 停止旧容器..."
docker compose -f /tmp/docker-compose-server.yml down 2>/dev/null || true

# 强制删除可能残留的容器
echo "🧹 清理残留容器..."
docker rm -f ppanel-mysql ppanel-redis ppanel-server 2>/dev/null || true

# 清理可能存在的网络冲突
echo "🔧 检查网络配置..."
if docker network inspect ppanel-network >/dev/null 2>&1; then
    echo "   网络 ppanel-network 已存在，将复用"
else
    echo "   创建网络 ppanel-network"
    docker network create ppanel-network 2>/dev/null || true
fi

# 启动新容器
echo "🚀 启动应用..."
docker compose -f /tmp/docker-compose-server.yml up -d

# 等待容器启动
echo "⏳ 等待容器启动（MySQL 初始化需要约 30 秒）..."
sleep 35

# 显示状态
echo ""
echo "========================================="
echo "📊 容器状态"
echo "========================================="
docker compose -f /tmp/docker-compose-server.yml ps

# 显示日志
echo ""
echo "========================================="
echo "📝 最近日志"
echo "========================================="
docker compose -f /tmp/docker-compose-server.yml logs --tail=30 server

echo ""
echo "========================================="
echo "✅ 部署完成！"
echo "========================================="
echo ""
echo "🌐 访问地址："
echo "   API 服务: http://${VM_IP}:8080"
echo "   初始化页面: http://${VM_IP}:8080/init"
echo ""
echo "🔑 数据库信息（初始化时使用）："
echo "   MySQL 主机: mysql"
echo "   MySQL 端口: 3306"
echo "   MySQL 用户: ppanel"
echo "   MySQL 密码: ppanel_password"
echo "   MySQL 数据库: ppanel"
echo "   Redis 主机: redis"
echo "   Redis 端口: 6379"
echo "   Redis 密码: (留空)"
echo ""
echo "📝 管理命令："
echo "   查看日志: docker compose -f /tmp/docker-compose-server.yml logs -f"
echo "   查看服务日志: docker compose -f /tmp/docker-compose-server.yml logs -f server"
echo "   重启应用: docker compose -f /tmp/docker-compose-server.yml restart"
echo "   停止应用: docker compose -f /tmp/docker-compose-server.yml down"
echo "   更新应用: cd $PROJECT_ROOT && ./scripts/deploy-from-source.sh"
echo ""
echo "💡 提示："
echo "   1. docker-compose 配置已保存到 /tmp/docker-compose-server.yml"
echo "   2. 首次部署请访问 http://${VM_IP}:8080/init 完成初始化"
echo "   3. 数据持久化在 Docker volumes 中"
echo ""
