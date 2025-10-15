# 🚀 GitHub Actions 快速设置清单

## ✅ 配置检查清单

### 1. GitHub Secrets 设置（必需）
进入你的 GitHub 仓库 → Settings → Secrets and variables → Actions

#### 必需的 Secrets：
- [ ] `CLOUDFLARE_API_TOKEN` - 你的 Cloudflare API Token
- [ ] `CLOUDFLARE_ACCOUNT_ID` - 你的 Cloudflare Account ID

#### 可选的 Secrets：
- [ ] `PERMANENT_PASSWORD` - 永久保存功能密码（不设置则使用默认 123456）

### 2. 获取 Cloudflare 凭据

#### 获取 API Token：
1. [ ] 访问 https://dash.cloudflare.com/profile/api-tokens
2. [ ] 点击 "Create Token"
3. [ ] 选择 "Custom token"
4. [ ] 设置权限：
   - Account - Cloudflare Workers:Edit
   - Account - Account Settings:Read
   - Zone Resources - Include All zones（如需自定义域名）
   - Account Resources - Include All accounts
5. [ ] 复制 Token 并添加到 GitHub Secrets

#### 获取 Account ID：
1. [ ] 登录 https://dash.cloudflare.com/
2. [ ] 在右侧边栏找到 "Account ID"
3. [ ] 复制并添加到 GitHub Secrets

### 3. 部署验证

#### 自动部署：
- [ ] 推送代码到 `main` 或 `master` 分支
- [ ] 查看 GitHub Actions 页面确认部署成功
- [ ] 检查 Cloudflare Workers 控制台确认应用运行

## 🎯 自动创建的资源

工作流将自动创建以下 Cloudflare 资源：

### R2 存储桶：
- `filecodebox-r2-f6bd1dfe` （主存储桶）
- `filecodebox-r2-f6bd1dfe-preview` （预览存储桶）

### KV 命名空间：
- `filecodebox-kv-2c88c777` （主命名空间）
- `filecodebox-kv-2c88c777_preview` （预览命名空间）

## 📱 验证部署成功

部署成功后你应该能看到：
- [ ] GitHub Actions 显示绿色对勾 ✅
- [ ] Cloudflare Workers 控制台中出现新的 Worker
- [ ] 可以访问 Worker 的 URL 并看到 FileCodeBox 界面
- [ ] 可以正常上传和下载文件

## 🎉 完成！

配置完成后，你的 FileCodeBox 将：
- ✅ 自动部署到 Cloudflare Workers
- ✅ 自动创建和管理所需的云资源
- ✅ 支持文件和文本分享
- ✅ 具备完整的 CI/CD 流程

享受自动化部署的便利！🚀