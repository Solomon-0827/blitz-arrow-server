# ⚡ 后端快速部署 - GCP

VM IP: **34.177.90.11**

---

## 🚀 部署步骤

### 1. SSH 连接
```bash
ssh user@34.177.90.11
```

### 2. 克隆代码
```bash
cd ~
git clone YOUR_REPO_URL blitz-arrow-server
cd blitz-arrow-server
```

### 3. 一键部署
```bash
./scripts/deploy-from-source.sh
```

脚本会自动：
- 安装 Docker 和 Go（如果未安装）
- 编译 Go 应用
- 构建 Docker 镜像
- 启动 MySQL、Redis、Server 容器

### 4. 初始化数据库

访问 http://34.177.90.11:8080/init 完成初始化：
- MySQL 主机: `mysql:3306`
- MySQL 用户: `ppanel`
- MySQL 密码: `ppanel_password`
- MySQL 数据库: `ppanel`
- Redis: `redis:6379` (无密码)

---

## 🌐 访问地址

- **API**: http://34.177.90.11:8080
- **初始化**: http://34.177.90.11:8080/init

---

## 📝 管理命令

### 查看状态
```bash
docker ps
```

### 查看日志
```bash
cd ~/blitz-arrow-server
docker compose -f deploy/docker-compose.prod.yml logs -f server
```

### 重启服务
```bash
cd ~/blitz-arrow-server
docker compose -f deploy/docker-compose.prod.yml restart
```

### 更新代码
```bash
cd ~/blitz-arrow-server
git pull
./scripts/deploy-from-source.sh
```

---

## 🔄 VM 重启后

容器配置了 `restart: always`，会自动启动。

**检查状态：**
```bash
docker ps
```

**手动启动：**
```bash
cd ~/blitz-arrow-server
docker compose -f deploy/docker-compose.prod.yml up -d
```

---

## 🛠️ 故障排查

### 查看日志
```bash
docker logs ppanel-server
docker logs ppanel-mysql
docker logs ppanel-redis
```

### 检查数据库连接
```bash
docker exec ppanel-mysql mysqladmin ping -h localhost
```

### 检查 Redis 连接
```bash
docker exec ppanel-redis redis-cli ping
```

### 进入容器调试
```bash
docker exec -it ppanel-server sh
docker exec -it ppanel-mysql mysql -uppanel -pppanel_password ppanel
```

---

## 📊 配置文件位置

- **后端配置**: `etc/ppanel.yaml`
- **Docker Compose**: `deploy/docker-compose.prod.yml`
- **部署脚本**: `scripts/deploy-from-source.sh`

---

## 💾 数据持久化

数据存储在 Docker volumes 中，重启不会丢失：
- `mysql_data` - MySQL 数据
- `redis_data` - Redis 数据

**查看 volumes：**
```bash
docker volume ls
```
