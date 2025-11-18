# ⚡ 快速部署 - GCP 虚拟机

VM IP: **136.110.11.215**

---

## 🚀 后端部署（先执行）

```bash
# 1. SSH 连接虚拟机
ssh user@136.110.11.215

# 2. 克隆代码
cd ~
git clone YOUR_REPO_URL blitz-arrow-server
cd blitz-arrow-server

# 3. 一键部署
./scripts/deploy-from-source.sh

# 4. 初始化（浏览器访问）
# http://136.110.11.215:8080/init
# MySQL: mysql:3306, ppanel/ppanel_password, ppanel
# Redis: redis:6379, 无密码
```

---

## 🎨 前端部署（后执行）

```bash
# 1. 克隆代码
cd ~
git clone YOUR_REPO_URL blitz-arrow
cd blitz-arrow

# 2. 一键部署（自动配置环境变量）
./scripts/deploy-from-source.sh
```

---

## 🔥 防火墙

```bash
gcloud compute firewall-rules create allow-ppanel-all \
  --allow tcp:3000,tcp:3001,tcp:8080 \
  --direction INGRESS
```

---

## 🌐 访问地址

- Admin: http://136.110.11.215:3000
- User: http://136.110.11.215:3001
- API: http://136.110.11.215:8080

---

## 📝 管理命令

```bash
# 查看容器
docker ps

# 查看日志
docker logs ppanel-server
docker logs ppanel-admin

# 重启
docker restart ppanel-server
docker restart ppanel-admin
```

---

完整文档：`完整部署指南.md`

