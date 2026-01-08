# RemoteTerminal

iOS SSH终端客户端，支持连接局域网或Tailscale网络内的Mac/Windows终端。

## 功能

- SSH密码认证
- 终端渲染（支持ANSI颜色、光标）
- 特殊按键支持（Ctrl+C、Tab、方向键等）
- 连接管理（增删改）
- 密码安全存储（Keychain）

## 环境要求

- macOS（用于编译）
- iOS 17.0+
- Xcode 15.0+

## 快速开始

### 一键安装

```bash
# 克隆仓库
git clone https://github.com/xiangli-sophgo/RemoteTerminal.git
cd RemoteTerminal

# 首次设置（自动安装依赖、生成项目）
./start.sh setup

# 在模拟器上运行
./start.sh run

# 或在真机上运行
./start.sh run -d
```

### 使用 Make

```bash
make setup      # 首次设置
make run        # 模拟器运行
make run-device # 真机运行
make xcode      # 打开 Xcode
```

## 脚本命令

| 命令 | 说明 |
|------|------|
| `./start.sh setup` | 首次设置（生成项目、安装依赖） |
| `./start.sh build` | 编译项目 |
| `./start.sh run` | 在模拟器上运行 |
| `./start.sh run -d` | 在真机上运行 |
| `./start.sh xcode` | 打开 Xcode |
| `./start.sh clean` | 清理构建文件 |
| `./start.sh config` | 配置签名 |
| `./start.sh status` | 显示项目状态 |

## 签名配置

### 免费 Apple ID

使用免费 Apple ID 签名的应用有效期为 7 天，过期后需要重新安装。

```bash
# 配置签名
./start.sh config

# 输入你的 Development Team ID
# 可以在 Xcode > Preferences > Accounts 中查看
```

### 付费开发者账户

使用付费账户（$99/年）签名的应用有效期为 1 年。

## 依赖项

脚本会自动安装以下依赖：

| 工具 | 用途 | 安装命令 |
|-----|------|---------|
| XcodeGen | 生成 Xcode 项目 | `brew install xcodegen` |
| CocoaPods | 依赖管理 | `gem install cocoapods` |
| ios-deploy | 真机安装（可选） | `brew install ios-deploy` |

## 服务端配置

### Mac 启用 SSH

```bash
# 系统偏好设置 → 共享 → 远程登录
# 或命令行：
sudo systemsetup -setremotelogin on
```

### Windows 启用 SSH

```powershell
# 设置 → 应用 → 可选功能 → 添加功能 → OpenSSH服务器
# 或 PowerShell：
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'
```

## 使用说明

1. 点击 + 添加 SSH 连接
2. 填写主机地址（局域网 IP 或 Tailscale IP）、用户名、密码
3. 点击连接即可使用终端

## 目录结构

```
RemoteTerminal/
├── start.sh                    # 自动化脚本
├── Makefile                    # Make 命令
├── project.yml                 # XcodeGen 配置
├── Podfile                     # CocoaPods 配置
├── RemoteTerminal/
│   ├── Info.plist              # iOS 配置
│   ├── App/
│   │   └── RemoteTerminalApp.swift
│   ├── Models/
│   │   └── SSHConnection.swift
│   ├── Views/
│   │   ├── ConnectionListView.swift
│   │   ├── ConnectionEditView.swift
│   │   ├── TerminalContainerView.swift
│   │   └── SpecialKeysBar.swift
│   ├── Services/
│   │   ├── SSHService.swift
│   │   └── TerminalSession.swift
│   └── Utils/
│       └── KeychainHelper.swift
```

## 故障排除

### 找不到 xcodegen 命令

```bash
brew install xcodegen
```

### Pod install 失败

```bash
sudo gem install cocoapods
pod repo update
pod install
```

### 签名错误

1. 运行 `./start.sh config` 配置 Team ID
2. 或在 Xcode 中手动选择 Team

### 真机无法安装

1. 确保设备已信任电脑
2. 在设备上：设置 → 通用 → VPN与设备管理 → 信任开发者

## 手动安装（备选方案）

如果自动化脚本不工作，可以手动安装：

1. 安装工具：`brew install xcodegen && gem install cocoapods`
2. 生成项目：`xcodegen generate`
3. 安装依赖：`pod install`
4. 打开项目：`open RemoteTerminal.xcworkspace`
5. 在 Xcode 中选择 Team 并运行

## License

MIT
