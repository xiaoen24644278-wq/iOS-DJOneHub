# DJOneHub for iOS 编译部署指南

## 目录

1. [环境准备](#1-环境准备)
2. [获取源码](#2-获取源码)
3. [创建 Xcode 项目](#3-创建-xcode-项目)
4. [配置项目](#4-配置项目)
5. [添加源代码](#5-添加源代码)
6. [配置权限和能力](#6-配置权限和能力)
7. [编译运行](#7-编译运行)
8. [打包 IPA](#8-打包-ipa)
9. [安装到设备](#9-安装到设备)
10. [常见问题](#10-常见问题)

---

## 1. 环境准备

### 必需硬件
- **Mac 电脑**（Apple Silicon 或 Intel）
  - macOS 13 Ventura 或更高版本
  - 至少 50GB 可用磁盘空间
- **iPhone 或 iPad**（用于测试）
  - iOS 16.0+ / iPadOS 16.0+
- **大疆第一代 4G 模块**
- **USB 线缆**（支持数据传输）

### 必需软件
- **Xcode 15.0+**（从 App Store 安装）
- **Git**（Xcode 自带）
- **Apple 开发者账号**（$99/年，用于真机调试和打包）
  - 免费账号也可以真机调试，但应用 7 天后会过期

### 可选工具
- **Apple Configurator 2**（用于安装 IPA 到设备）
- **iMazing**（第三方设备管理工具）
- **Transporter**（上传到 App Store Connect）

---

## 2. 获取源码

将本项目的源码文件夹复制到你的 Mac 上，或者使用 Git 克隆：

```bash
# 如果项目托管在 Git 仓库
git clone <repository-url> DJOneHub-iOS
cd DJOneHub-iOS
```

确保源码目录结构完整：

```
DJOneHub-iOS/
├── DJOneHub/
│   ├── DJOneHubApp.swift
│   ├── Info.plist
│   ├── Assets.xcassets/
│   ├── Models/
│   ├── Services/
│   ├── ViewModels/
│   ├── Views/
│   └── Utilities/
├── README.md
└── BUILD_GUIDE.md
```

---

## 3. 创建 Xcode 项目

由于本项目提供的是源代码而非 `.xcodeproj` 文件，你需要在 Xcode 中创建一个新项目并导入源码。

### 步骤

1. 打开 **Xcode**
2. 选择 **File → New → Project...**
3. 选择 **iOS → App**，点击 **Next**
4. 填写项目信息：
   - **Product Name**: `DJOneHub`
   - **Team**: 选择你的开发者团队
   - **Organization Identifier**: 你的反向域名（如 `com.yourname`）
   - **Interface**: `SwiftUI`
   - **Language**: `Swift`
   - 取消勾选 **Use Core Data**、**Include Tests**
5. 点击 **Next**，选择保存位置（建议保存到 `DJOneHub-iOS` 目录的同级目录）
6. 点击 **Create**

---

## 4. 配置项目

### 4.1 基础配置

1. 在 Xcode 左侧项目导航器中，点击最顶部的 **DJOneHub** 项目文件
2. 选择 **TARGETS → DJOneHub**
3. 在 **General** 标签页中：
   - **Minimum Deployments**: iOS 16.0
   - **Device Orientation**:
     - iPhone: 勾选 Portrait、Landscape Left、Landscape Right
     - iPad: 勾选全部四个方向
   - **Status Bar Style**: Default
   - 勾选 **Requires full screen**（如果不需要多任务分屏）

### 4.2 Bundle Identifier

确保 Bundle Identifier 唯一，例如：
```
com.yourname.djonehub
```

### 4.3 版本号

- **Version**: `1.0.0`
- **Build**: `1`

---

## 5. 添加源代码

### 5.1 替换 App 入口文件

1. 在 Xcode 中删除默认创建的 `DJOneHubApp.swift`（或 `ContentView.swift`）
2. 将源码目录中的所有 `.swift` 文件拖入 Xcode 项目
3. 在弹出的对话框中：
   - 勾选 **Copy items if needed**
   - 选择 **Create groups**
   - 勾选 **Add to targets: DJOneHub**
4. 点击 **Finish**

### 5.2 替换 Info.plist

1. 在 Xcode 中删除默认的 `Info.plist`
2. 将源码中的 `Info.plist` 拖入项目
3. 或者直接在 Xcode 中编辑 Info.plist，确保包含以下键值：

```xml
<!-- 外部附件协议 -->
<key>UISupportedExternalAccessoryProtocols</key>
<array>
    <string>com.dji.cellular.at</string>
    <string>com.dji.cellular.usb</string>
</array>

<!-- 后台模式 -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>external-accessory</string>
    <string>fetch</string>
    <string>voip</string>
</array>

<!-- 权限描述 -->
<key>NSContactsUsageDescription</key>
<string>需要访问通讯录以匹配来电号码和快速拨号</string>
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限以进行通话</string>

<!-- 界面方向 -->
<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>
<key>UISupportedInterfaceOrientations~ipad</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationPortraitUpsideDown</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>
```

### 5.3 添加 Assets

将源码中的 `Assets.xcassets` 文件夹替换 Xcode 默认创建的资源目录。

---

## 6. 配置权限和能力

### 6.1 Signing & Capabilities

1. 进入 **TARGETS → DJOneHub → Signing & Capabilities**
2. 确保 **Automatically manage signing** 已勾选
3. 选择正确的 **Team**
4. 点击 **+ Capability**，添加以下能力：
   - **Background Modes**：
     - ✅ Audio, AirPlay, and Picture in Picture
     - ✅ External Accessory communication
     - ✅ Background fetch
     - ✅ Voice over IP
   - **Access Wi-Fi Information**（可选，用于网络诊断）

### 6.2 外部附件配置

大疆4G模块需要通过 ExternalAccessory 框架通信。在 Info.plist 中配置的协议字符串需要与模块实际支持的协议匹配。

如果模块不支持 MFi 协议，你可能需要：
1. 使用 IOKit 框架（需要特殊权限，仅限企业级开发者账号）
2. 或者通过网络接口与模块通信（模块作为 USB 网卡，通过 HTTP API 交互）

### 6.3 通讯录权限

在 Info.plist 中配置 `NSContactsUsageDescription` 后，首次访问通讯录时系统会自动弹出权限请求。

### 6.4 麦克风权限

在 Info.plist 中配置 `NSMicrophoneUsageDescription`，通话功能需要麦克风权限。

---

## 7. 编译运行

### 7.1 选择目标设备

1. 用 USB 线将 iPhone / iPad 连接到 Mac
2. 在 Xcode 顶部的设备选择器中选择你的设备
3. 首次连接需要在设备上点击"信任此电脑"

### 7.2 编译

1. 按 **Command + B** 编译项目
2. 检查是否有编译错误
3. 如果有错误，根据错误提示修复

### 7.3 运行

1. 按 **Command + R** 运行到设备
2. 应用会自动安装并启动
3. 首次启动会请求各种权限，点击允许

### 7.4 连接模块测试

1. 将大疆4G模块通过 USB 连接到 iPhone / iPad（可能需要 USB-C 转 USB-A 转接头）
2. 打开 DJOneHub 应用
3. 查看顶部状态栏是否显示"已连接"
4. 进入"设置 → 模块状态"查看详细信息
5. 测试拨号、发短信等功能

---

## 8. 打包 IPA

### 8.1 Archive 打包

1. 在 Xcode 中选择 **Any iOS Device (arm64)** 作为目标设备
2. 选择 **Product → Archive**
3. 等待编译和归档完成
4. 归档完成后会自动弹出 **Organizer** 窗口

### 8.2 导出 IPA

1. 在 Organizer 中选择刚才的归档
2. 点击 **Distribute App**
3. 选择分发方式：
   - **Ad Hoc**：安装到指定设备（推荐测试用）
   - **Enterprise**：企业内部分发（需要企业账号）
   - **App Store Connect**：上传到 App Store
   - **Development**：开发测试用
4. 点击 **Next**
5. 选择签名方式（推荐 **Automatically manage signing**）
6. 点击 **Next**，等待处理
7. 点击 **Export**，选择保存位置
8. 导出完成后会得到一个 `.ipa` 文件

### 8.3 导出选项说明

| 选项 | 用途 | 限制 |
|------|------|------|
| Development | 开发测试 | 仅限注册的测试设备，7天过期（免费账号） |
| Ad Hoc | 小范围测试 | 最多100台设备，需要注册设备UDID |
| Enterprise | 企业内部分发 | 需要企业账号($299/年)，无设备数量限制 |
| App Store | 公开发布 | 需要通过苹果审核 |

---

## 9. 安装到设备

### 9.1 通过 Xcode 安装

1. 连接设备到 Mac
2. 在 Xcode 中选择 **Window → Devices and Simulators**
3. 选择你的设备
4. 点击 **+** 按钮，选择导出的 `.ipa` 文件
5. 等待安装完成

### 9.2 通过 Apple Configurator 2 安装

1. 从 App Store 安装 **Apple Configurator 2**
2. 连接设备到 Mac
3. 打开 Apple Configurator 2
4. 将 `.ipa` 文件拖入设备
5. 等待安装完成

### 9.3 通过 iMazing 安装

1. 下载并安装 **iMazing**
2. 连接设备
3. 选择 **Apps**
4. 点击 **Install .ipa**
5. 选择文件并安装

### 9.4 信任开发者证书

如果是 Ad Hoc 或 Development 方式安装，首次打开应用时会提示"未受信任的企业级开发者"：

1. 打开 **设置 → 通用 → VPN与设备管理**
2. 在"开发者App"下找到你的证书
3. 点击信任
4. 返回桌面打开应用

---

## 10. 常见问题

### Q1: 编译报错 "No such module 'ExternalAccessory'"

**A**: ExternalAccessory 是 iOS 系统框架，不需要额外安装。确保：
- 项目 Deployment Target 是 iOS 16.0+
- 在 Build Phases → Link Binary With Libraries 中添加 `ExternalAccessory.framework`

### Q2: 模块连接后应用识别不到

**A**: 可能的原因：
1. USB 线缆只支持充电，不支持数据传输 → 更换数据线
2. 模块不支持 MFi 协议 → 需要使用 IOKit 或网络接口方式
3. 协议字符串不匹配 → 检查 Info.plist 中的 `UISupportedExternalAccessoryProtocols`
4. 模块未进入正确的 USB 模式 → 先在 Mac 上用 DJOneHub 设置为 iPhone/iPad 模式

### Q3: iPad 横屏时布局不正确

**A**: 确保：
- Info.plist 中 `UISupportedInterfaceOrientations~ipad` 包含横屏方向
- 项目设置中 iPad 勾选了横屏方向
- 使用了 `NavigationSplitView` 或自适应布局

### Q4: 短信发送失败

**A**: 检查：
1. SIM 卡是否正常识别（设置 → 模块状态 → SIM 状态）
2. 是否有信号
3. 短信中心号码是否正确
4. SIM 卡是否欠费或被限制短信功能

### Q5: 通话没有声音

**A**: 双向通话需要：
1. 模块支持 USB Audio（完整模式下）
2. 模块侧语音运行时已加载
3. 运营商支持 VoLTE / IMS
4. 应用已获得麦克风权限

注意：iPhone/iPad 模式下关闭了 USB Audio，通话音频可能无法正常工作。

### Q6: 如何获取设备 UDID

**A**: 
1. 连接设备到 Mac
2. 打开 Xcode → Window → Devices and Simulators
3. 选择设备，Identifier 就是 UDID
4. 或者在 Apple Configurator 2 中查看设备信息

### Q7: 免费开发者账号的限制

**A**:
- 应用安装后 7 天过期，需要重新安装
- 最多同时安装 3 个应用
- 无法使用推送通知、Apple Pay 等高级功能
- 无法发布到 App Store

### Q8: 如何上传到 App Store

**A**:
1. 注册付费 Apple 开发者账号（$99/年）
2. 在 App Store Connect 中创建 App 记录
3. 在 Xcode 中 Archive 后选择 App Store Connect 分发
4. 等待上传完成
5. 在 App Store Connect 中填写应用信息
6. 提交审核
7. 审核通过后即可发布

---

## 技术支持

如果在编译或使用过程中遇到问题，可以：

1. 查看 Xcode 的编译错误信息和控制台日志
2. 检查 iOS 设备的系统日志（设置 → 隐私与安全性 → 分析与改进 → 分析数据）
3. 在 AT 控制台中发送测试指令验证模块通信
4. 参考原项目的文档和 Issue：https://github.com/rogerbush007-a11y/DJOneHub-mac-enhanced

---

## 更新日志

### v1.0.0 (2026-08-26)
- 初始 iOS 版本发布
- 完整的电话、短信、通讯录功能
- 网络管理、GPS、eSIM 支持
- AT 指令控制台
- SwiftUI 简洁风格界面
- iPad 横竖屏自适应布局
