# DJOneHub for iOS

基于 DJOneHub 开源项目移植的 iOS / iPadOS 应用，让大疆第一代 4G 模块成为 iPhone / iPad 上长期可用的实体 SIM 终端。

## 项目简介

DJOneHub 是一个非官方开源项目，通过大疆第一代 4G 模块已有的 USB 接口提供短信、4G、GPS、eSIM、来电及通话控制，不修改模块固件。

本项目是 macOS 版本的 iOS 移植，使用 SwiftUI 构建简洁风格的用户界面，完整支持 iPhone 和 iPad（含横竖屏自适应布局）。

## 功能特性

### 电话
- 拨号、接听、拒接、挂断
- DTMF 双音多频按键
- 通话记录管理
- 通话中静音 / 扬声器切换
- 来电通知（支持锁屏接听 / 拒接）
- 自动接听（可配置延迟）

### 短信
- 收发短信
- 验证码自动识别与预览
- 会话式对话界面
- 短信通知
- 读取后自动清理模块存储（可选）
- 从模块批量导入历史短信

### 通讯录
- 同步系统通讯录
- 联系人搜索
- 联系人详情（多号码支持）
- 快速拨号 / 发短信
- 添加 / 删除联系人

### 网络
- USB 4G 网络共享
- 移动数据开关
- 网络模式选择（自动 / 2G / 3G / 4G / 5G）
- APN 配置
- 数据漫游开关
- 流量统计
- 网络诊断工具

### GPS 定位
- 模块内置 GPS 启用 / 禁用
- 实时位置显示（地图）
- 经纬度、海拔、速度、航向
- 卫星状态（可见 / 使用数量）
- 定位质量显示

### eSIM 管理
- eUICC 信息读取（EID、固件、空间）
- Profile 列表管理
- 下载 / 启用 / 禁用 / 删除 Profile
- Profile 重命名

### AT 指令控制台
- 直接发送 AT 指令与模块通信
- 命令历史记录
- 常用指令快捷菜单
- 响应高亮显示

### 连接模式
- **完整模式**：启用 USB Audio、4G、AT 和短信全部接口
- **iPhone 模式**：关闭 USB Audio，保留 4G、AT 和短信
- **iPad 模式**：关闭 USB Audio，保留 4G、AT 和短信，优化大屏显示

## 技术架构

```
DJOneHub-iOS/
├── DJOneHub/
│   ├── DJOneHubApp.swift          # 应用入口
│   ├── Info.plist                 # 应用配置
│   ├── Assets.xcassets/           # 资源文件
│   ├── Models/                    # 数据模型层
│   │   ├── SMSMessage.swift       # 短信模型
│   │   ├── CallRecord.swift       # 通话记录模型
│   │   ├── Contact.swift          # 联系人模型
│   │   ├── ModuleStatus.swift     # 模块状态模型
│   │   └── NetworkStatus.swift    # 网络状态模型
│   ├── Services/                  # 服务层（核心业务逻辑）
│   │   ├── USBCommunicationManager.swift  # USB 通信管理
│   │   ├── ATCommandManager.swift         # AT 指令管理
│   │   ├── SMSManager.swift               # 短信管理
│   │   ├── CallManager.swift              # 通话管理
│   │   ├── ContactManager.swift           # 通讯录管理
│   │   ├── NetworkManager.swift           # 网络管理
│   │   ├── GPSManager.swift               # GPS 管理
│   │   └── eSIMManager.swift              # eSIM 管理
│   ├── ViewModels/                # 视图模型层
│   │   ├── PhoneViewModel.swift
│   │   ├── SMSViewModel.swift
│   │   ├── ContactsViewModel.swift
│   │   └── SettingsViewModel.swift
│   ├── Views/                     # UI 视图层（SwiftUI）
│   │   ├── MainTabView.swift      # 主标签页
│   │   ├── Components/            # 通用组件
│   │   ├── Phone/                 # 电话模块
│   │   ├── SMS/                   # 短信模块
│   │   ├── Contacts/              # 通讯录模块
│   │   └── Settings/              # 设置模块
│   └── Utilities/                 # 工具类
│       ├── ATCommandParser.swift  # AT 指令解析器
│       ├── DateFormatter+Extension.swift
│       ├── String+PhoneNumber.swift
│       └── UserDefaultsKeys.swift
├── README.md                      # 项目说明
└── BUILD_GUIDE.md                 # 编译部署指南
```

### 架构设计原则

1. **分层架构**：模型层 → 服务层 → 视图模型层 → 视图层，职责清晰
2. **单向数据流**：使用 Combine 框架实现响应式数据绑定
3. **单例服务**：各核心服务使用单例模式，确保全局状态一致
4. **协议抽象**：USB 通信层可替换为不同实现（ExternalAccessory / IOKit）
5. **自适应布局**：SwiftUI + SizeClass 实现 iPhone / iPad、横竖屏自适应

## iPad 横竖屏适配

本应用完整支持 iPad 横竖屏切换，适配策略如下：

### 横屏模式
- 使用 `NavigationSplitView` 侧边栏布局
- 左侧为功能导航（电话 / 短信 / 通讯录 / 设置）
- 右侧为详情内容区域
- 短信页面采用分栏布局（会话列表 + 对话内容）
- 更宽的内容区域，优化信息密度

### 竖屏模式
- 使用 `TabView` 底部标签栏布局
- 全屏单页展示
- 短信页面使用导航栈推入对话
- 与 iPhone 体验一致

### 自适应组件
- `AdaptiveLayoutContainer`：根据设备和方向自动选择 HStack / VStack
- `StatusBar`：顶部状态栏自适应宽度
- 所有列表和卡片使用系统自适应间距

## 系统要求

- **iOS 16.0+** / **iPadOS 16.0+**
- iPhone 或 iPad（支持 USB-C 或 Lightning 转 USB）
- 大疆第一代 4G 模块（USB 设备标识通常为 `2ca3:4006`）
- 可正常使用的实体 SIM 或兼容 eUICC/eSIM 卡片
- 支持数据传输的 USB 线缆

## 开源协议

本项目基于 **PolyForm Noncommercial License 1.0.0** 开源，仅允许非商业用途。

### 上游声明
```
Required Notice: Copyright iniwex5 (https://github.com/iniwex5/vohive)
```

### 第三方组件
- libusb 1.0.30 — GNU Lesser General Public License v2.1 or later
- 其他组件遵循各自许可证

## 致谢

- 原 VoHive 项目及作者 iniwex5
- DJOneHub macOS 增强版作者 rogerbush007-a11y
- libusb 及其他开源组件贡献者
- 参与大疆第一代 4G 模块研究、测试和资料分享的用户

## 免责声明

本项目不代表 DJI、Quectel、任何运营商或 eSIM 卡片厂商。相关商标和产品名称归各自权利人所有。

使用本软件所产生的任何风险由使用者自行承担。请遵守当地法律法规，不要将本软件用于非法用途。
