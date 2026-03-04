# ✨ LLM Bridge - 多平台 LLM 客户端 ✨

_支持 Ollama、LM Studio、Claude 和 OpenAI 的多平台 LLM 客户端_

[한국어](README-ko.md) • [English](README.md) • [日本語](README-jp.md) • [中文](README-cn.md)

# LLM Bridge

LLM Bridge 是一个多平台客户端应用，可以连接到包括 Ollama、LM Studio、Claude 和 OpenAI 在内的各种 LLM 服务。您可以下载源代码进行构建，或从 App Store 下载 LLM Bridge 应用。

## 介绍

LLM Bridge 是一个支持多个 LLM 平台的多功能客户端：

* **Ollama**: 用于本地运行 LLM 的开源软件
* **LM Studio**: 支持各种模型的本地 LLM 平台
* **Claude**: Anthropic 的高级 AI 模型
* **OpenAI**: 包含 GPT-5 在内的 GPT 模型的领先 AI 平台

## 主要功能

* **多 LLM 平台支持**：
  * 通过 Ollama 访问本地 LLM（`http://localhost:11434`）
  * LM Studio 集成（`http://localhost:1234`）
  * Claude API 支持 - 需要 API 密钥
  * OpenAI API 支持 - 需要 API 密钥
* **选择性服务显示**: 在模型选择菜单中选择要显示的 LLM 服务
* **远程 LLM 访问**: 通过 IP 地址连接到 Ollama/LM Studio 主机
* **自定义提示**: 支持设置自定义指令
* **各种开源 LLM 支持**（Deepseek、Llama、Gemma、Qwen、Mistral 等）
* **GPT-5 支持**: OpenAI GPT-5 模型支持，自动非流式回退
* **可自定义的指令设置**
* **高级模型参数**: 通过直观滑块控制 Temperature、Top P、Top K
* **连接测试**: 内置服务器连接状态检查器
* **多格式文件支持**: 图像、PDF 文档和文本文件
* **图像识别支持**（仅在支持的模型上）
* **改进的聊天 UI**: 用户/助手头像图标，重新设计的消息气泡
* **原生 Picker 模型选择**: 使用 macOS/iOS 原生 Picker 改进的提供者和模型选择
* **直观的聊天式 UI**
* **对话历史**: 保存和管理聊天会话
* **韩语、英语、日语、中文支持**
* **Markdown 格式支持**

## 平台支持

### 🖥️ macOS 支持

macOS 版本的 LLM Bridge 是作为针对桌面环境优化的原生 macOS 应用开发的。

#### macOS 主要特点:
- **本地 LLM**: 本地 LLM 连接
- **原生 macOS UI**: 遵循 macOS 设计指南的界面
- **侧边栏导航**: 将对话列表和主聊天区域分离的高效布局
- **模型选择菜单**: 从顶部工具栏轻松选择和切换模型
- **高级设置**: 详细的 LLM 参数调整和服务器配置
- **文件拖放**: 轻松上传图像和文档
- **键盘快捷键**: 提高生产力的快捷键

![macOS 主屏幕](mac.jpg)

![macOS 设置屏幕](mac_settings.jpg)

### 📱 iOS 支持

iOS 版本的 LLM Bridge 提供针对移动环境优化的界面。

#### iOS 主要特点:
- **本地 LLM**: 本地 LLM 连接
- **移动优化 UI**: 针对触摸界面优化的设计
- **基于标签的导航**: 用于轻松导航的直观标签结构
- **滑动手势**: 消息删除和管理
- **相机集成**: 照片拍摄和图像分析

#### iOS 截图画廊

<div style="display: flex; flex-wrap: wrap; gap: 10px;">
  <img src="iphone10.png" width="200">
  <img src="iphone01.png" width="200">
  <img src="iphone02.png" width="200">
  <img src="iphone03.png" width="200">
  <img src="iphone04.png" width="200">
  <img src="iphone05.png" width="200">
  <img src="iphone06.png" width="200">
  <img src="iphone07.png" width="200">
  <img src="iphone08.png" width="200">
  <img src="iphone09.png" width="200">
  <img src="iphone11.png" width="200">
</div>

## 使用方法

### 1. 选择您偏好的 LLM 平台:
* **Ollama**: 在计算机上安装 Ollama（[Ollama 下载](https://ollama.com/download)）
* **LM Studio**: 安装 LM Studio（[LM Studio 网站](https://lmstudio.ai)）
* **Claude/OpenAI**: 从各自平台获取 API 密钥

### 2. 下载应用:
* 下载源代码并用 Xcode 构建，或
* 从 App Store 下载 LLM Bridge 应用

### 3. 配置您选择的平台:
* **Ollama/LM Studio**: 安装所需的模型
* **Claude/OpenAI**: 在设置中输入您的 API 密钥

### 4. 对于本地 LLM（Ollama/LM Studio）:
* 根据需要配置远程访问

### 5. 启动 LLM Bridge:
* 选择您偏好的服务和模型
* 开始您的对话！

## 系统要求

### macOS 要求:
- macOS 12.0（Monterey）或更高版本
- 本地 LLM: 安装了 Ollama 或 LM Studio 的计算机
- 云 LLM: Claude 或 OpenAI 的有效 API 密钥
- 网络连接

### iOS 要求:
- iOS 15.0 或更高版本
- 本地 LLM: 同一网络内安装了 Ollama 或 LM Studio 的计算机
- 云 LLM: Claude 或 OpenAI 的有效 API 密钥
- Wi-Fi 或蜂窝连接

## 优势

* **支持本地和基于云的 LLM**
* **为流式界面提供灵活的服务选择**
* **通过各种平台提供高级 AI 功能**
* **隐私保护选项（本地 LLM）**
* **适用于编程、创意工作、一般问题等的多功能性**
* **有组织的对话管理**

## 技术特点

### 架构
- **SwiftUI**: 现代声明式 UI 框架
- **Combine**: 响应式编程框架
- **Async/Await**: 异步任务处理
- **Core Data**: 本地数据存储和管理

### 网络
- **URLSession**: 高效的 HTTP 通信
- **Server-Sent Events**: 实时流式响应
- **JSON**: 标准数据交换格式
- **Base64**: 图像编码

### 安全
- **HTTPS**: 安全通信
- **API 密钥管理**: 安全认证信息存储
- **本地处理**: 通过本地 LLM 支持保护隐私

## 注意事项

* 本地 LLM 功能需要安装 Ollama 或 LM Studio
* Claude 和 OpenAI 服务需要 API 密钥
* 您有责任安全地管理您的本地 LLM 主机和 API 密钥

## 应用下载

对于构建有困难的用户，您可以从以下链接下载应用。

* **macOS**: [Mac App Store](https://apps.apple.com/us/app/mac-ollama-client/id6741420139)
* **iOS**: [App Store](https://apps.apple.com/us/app/llm-bridge-multi-llm-client/id6738298481?platform=iphone)

## 许可证

LLM Bridge 在 GNU 许可证下提供。有关更多信息，请参阅 LICENSE 文件。

## 联系

有关 LLM Bridge 的问题或错误报告，请发送电子邮件至 rtlink.park@gmail.com。

## 贡献

此项目是开源的，欢迎贡献。通过错误报告、功能请求和拉取请求帮助改进项目。

## 更新日志

有关详细更改，请参阅 [changelog.md](changelog.md)。

---

**LLM Bridge** - 连接各种 LLM 的多平台客户端 