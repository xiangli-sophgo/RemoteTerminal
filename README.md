# RemoteTerminal

iOS SSH终端客户端，支持连接局域网或Tailscale网络内的Mac/Windows终端。

## 功能

- SSH密码认证
- 终端渲染（支持ANSI颜色、光标）
- 特殊按键支持（Ctrl+C、Tab、方向键等）
- 连接管理（增删改）
- 密码安全存储（Keychain）

## 环境要求

- iOS 17.0+
- Xcode 15.0+
- CocoaPods

## 安装步骤

### 1. 在Xcode中创建项目

1. 打开Xcode，选择 **File → New → Project**
2. 选择 **iOS → App**
3. 填写信息：
   - Product Name: `RemoteTerminal`
   - Organization Identifier: 你的标识符
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Storage: `SwiftData`
4. 保存到 `RemoteTerminal` 目录（与现有文件同级）

### 2. 安装依赖

```bash
cd RemoteTerminal
pod install
```

### 3. 添加SwiftTerm

1. 打开 `RemoteTerminal.xcworkspace`（注意是workspace）
2. 选择项目 → Package Dependencies
3. 点击 + 添加包
4. 输入URL: `https://github.com/migueldeicaza/SwiftTerm`
5. 选择版本规则（Up to Next Major Version）

### 4. 替换源文件

将本仓库中的Swift文件复制到Xcode项目对应目录：
- `RemoteTerminal/App/` → App入口
- `RemoteTerminal/Models/` → 数据模型
- `RemoteTerminal/Views/` → 视图文件
- `RemoteTerminal/Services/` → 服务层
- `RemoteTerminal/Utils/` → 工具类

### 5. 配置Info.plist

在Info.plist中添加：

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>用于连接局域网内的SSH服务器</string>
```

### 6. 编译运行

使用 `Cmd + R` 运行项目。

## 服务端配置

### Mac启用SSH

```bash
# 系统偏好设置 → 共享 → 远程登录
# 或命令行：
sudo systemsetup -setremotelogin on
```

### Windows启用SSH

```powershell
# 设置 → 应用 → 可选功能 → 添加功能 → OpenSSH服务器
# 或PowerShell：
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'
```

## 使用说明

1. 点击 + 添加SSH连接
2. 填写主机地址（局域网IP或Tailscale IP）、用户名、密码
3. 点击连接即可使用终端

## 目录结构

```
RemoteTerminal/
├── App/
│   └── RemoteTerminalApp.swift
├── Models/
│   └── SSHConnection.swift
├── Views/
│   ├── ConnectionListView.swift
│   ├── ConnectionEditView.swift
│   ├── TerminalContainerView.swift
│   └── SpecialKeysBar.swift
├── Services/
│   ├── SSHService.swift
│   └── TerminalSession.swift
└── Utils/
    └── KeychainHelper.swift
```
