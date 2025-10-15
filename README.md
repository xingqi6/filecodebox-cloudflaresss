# FileCodeBox on Cloudflare Workers

一个可匿名分享文件/文本、支持提取码的 Cloudflare Workers 应用。

## 🚀 功能特性

- 📁 **文件分享**: 支持最大 90MB 文件上传和分享
- 📝 **文本分享**: 支持文本内容快速分享
- 🔢 **提取码系统**: 6位数字提取码，安全便捷
- ⏰ **自动过期**: 支持按时间或次数自动清理
- 📱 **现代界面**: 响应式设计，支持移动端
- 🔗 **二维码分享**: 自动生成分享二维码
- 🛡️ **速率限制**: 内置防滥用保护

## 🎯 快速开始

### GitHub Actions 自动部署（推荐）

1. **设置 GitHub Secrets**:
   - `CLOUDFLARE_API_TOKEN` - 你的 Cloudflare API Token
   - `CLOUDFLARE_ACCOUNT_ID` - 你的 Cloudflare Account ID

2. **推送代码到 main 分支**，GitHub Actions 将自动：
   - 创建 Cloudflare R2 存储桶和 KV 命名空间
   - 配置应用设置
   - 部署到 Cloudflare Workers

3. **查看部署结果**:
   - 在 GitHub Actions 页面查看部署状态
   - 在 Cloudflare Workers 控制台获取访问链接

## 🔧 配置选项

### 环境变量
- `MAX_FILE_SIZE` - 文件最大尺寸（MB），默认 90
- `MAX_TEXT_SIZE` - 文本最大尺寸（MB），默认 1
- `QR_API` - 二维码服务地址
- `NOTICE_TTL_HOURS` - 声明弹窗间隔（小时），默认 24

### 速率限制
- `UPLOAD_FILE_RPM` - 文件上传每分钟限制，默认 10
- `UPLOAD_TEXT_RPM` - 文本上传每分钟限制，默认 20
- `DOWNLOAD_RPM` - 下载每分钟限制，默认 60

## 🛡️ 安全特性

- 基于 IP 的速率限制
- 自动文件过期清理
- 密码保护的永久保存功能
- 内容类型验证

## 📄 许可证

MIT License