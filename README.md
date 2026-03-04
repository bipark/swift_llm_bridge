# ✨ LLM Bridge - Multi LLM Client ✨

_Multi-platform LLM client supporting Ollama, LM Studio, Claude, and OpenAI_

[한국어](README-ko.md) • [English](README.md) • [日本語](README-jp.md) • [中文](README-cn.md)

# LLM Bridge

LLM Bridge is a multi-platform client app that allows you to connect to various LLM services including Ollama, LM Studio, Claude, and OpenAI. You can download and build the source code or download the LLM Bridge app from the App Store.

## Introduction

LLM Bridge is a versatile client that supports multiple LLM platforms:

* **Ollama**: Open source software for running LLMs locally
* **LM Studio**: Local LLM platform with various model support
* **Claude**: Anthropic's advanced AI model
* **OpenAI**: Leading AI platform including GPT-5 and other GPT models

## Key Features

* **Multiple LLM Platform Support**:
  * Local LLM access via Ollama (`http://localhost:11434`)
  * LM Studio integration (`http://localhost:1234`)
  * Claude API support - API Key required
  * OpenAI API support - API Key required
* **Selective Service Display**: Choose which LLM services to show in the model selection menu
* **Remote LLM Access**: Connect to Ollama/LM Studio host via IP address
* **Custom Prompts**: Support for setting custom instructions
* **Various Open Source LLMs Support** (Deepseek, Llama, Gemma, Qwen, Mistral, etc.)
* **GPT-5 Support**: OpenAI GPT-5 model support with automatic non-streaming fallback
* **Customizable Instruction Settings**
* **Advanced Model Parameters**: Temperature, Top P, Top K controls with intuitive sliders
* **Connection Testing**: Built-in server connection status checker
* **Multi-format File Support**: Images, PDF documents, and text files
* **Image Recognition Support** (only on models that support it)
* **Improved Chat UI**: Avatar icons for user and assistant, redesigned message bubbles
* **Native Picker for Model Selection**: Improved provider and model selection using native macOS/iOS Picker
* **Intuitive Chat-like UI**
* **Conversation History**: Save and manage chat sessions
* **Korean, English, Japanese, Chinese Support**
* **Markdown Format Support**

## Platform Support

### 🖥️ macOS Support

macOS version of LLM Bridge is developed as a native macOS app optimized for desktop environment.

#### macOS Key Features:
- **Local LLM**: Local LLM connection
- **Native macOS UI**: Interface following macOS design guidelines
- **Sidebar Navigation**: Efficient layout separating conversation list and main chat area
- **Model Selection Menu**: Easy model selection and switching from top toolbar
- **Advanced Settings**: Detailed LLM parameter adjustment and server configuration
- **File Drag and Drop**: Easy upload of images and documents
- **Keyboard Shortcuts**: Productivity-enhancing shortcuts

![macOS Main Screen](mac.jpg)

![macOS Settings Screen](mac_settings.jpg)

### 📱 iOS Support

iOS version of LLM Bridge provides an interface optimized for mobile environment.

#### iOS Key Features:
- **Local LLM**: Local LLM connection
- **Mobile Optimized UI**: Design optimized for touch interface
- **Tab-based Navigation**: Intuitive tab structure for easy navigation
- **Swipe Gestures**: Message deletion and management
- **Camera Integration**: Photo capture and image analysis

#### iOS Screenshot Gallery

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

## How to Use

### 1. Choose your preferred LLM platform:
* **Ollama**: Install Ollama on your computer ([Ollama Download](https://ollama.com/download))
* **LM Studio**: Install LM Studio ([LM Studio Website](https://lmstudio.ai))
* **Claude/OpenAI**: Obtain API keys from respective platforms

### 2. Download the app:
* Download source and build with Xcode, or
* Download LLM Bridge app from App Store

### 3. Configure your chosen platform:
* **Ollama/LM Studio**: Install desired models
* **Claude/OpenAI**: Enter your API keys in settings

### 4. For local LLMs (Ollama/LM Studio):
* Configure remote access if needed

### 5. Launch LLM Bridge:
* Select your preferred service and model
* Start your conversation!

## System Requirements

### macOS Requirements:
- macOS 12.0 (Monterey) or later
- Local LLM: Computer with Ollama or LM Studio installed
- Cloud LLM: Valid API keys for Claude or OpenAI
- Network connection

### iOS Requirements:
- iOS 15.0 or later
- Local LLM: Computer with Ollama or LM Studio installed on the same network
- Cloud LLM: Valid API keys for Claude or OpenAI
- Wi-Fi or cellular connection

## Advantages

* **Support for both local and cloud-based LLMs**
* **Flexible service selection for streamlined interface**
* **Advanced AI features available through various platforms**
* **Privacy protection options (local LLMs)**
* **Versatile for programming, creative work, casual questions, etc.**
* **Organized conversation management**

## Technical Features

### Architecture
- **SwiftUI**: Modern declarative UI framework
- **Combine**: Reactive programming framework
- **Async/Await**: Asynchronous task handling
- **Core Data**: Local data storage and management

### Networking
- **URLSession**: Efficient HTTP communication
- **Server-Sent Events**: Real-time streaming responses
- **JSON**: Standard data exchange format
- **Base64**: Image encoding

### Security
- **HTTPS**: Secure communication
- **API Key Management**: Secure authentication information storage
- **Local Processing**: Privacy protection through local LLM support

## Notes

* Local LLM features require Ollama or LM Studio installation
* API keys required for Claude and OpenAI services
* You are responsible for managing your local LLM hosts and API keys securely

## App Download

For those who have difficulty building, you can download the app from the links below.

* **macOS**: [Mac App Store](https://apps.apple.com/us/app/mac-ollama-client/id6741420139)
* **iOS**: [App Store](https://apps.apple.com/us/app/llm-bridge-multi-llm-client/id6738298481?platform=iphone)

## License

LLM Bridge is licensed under the GNU license. For more information, please refer to the LICENSE file.

## Contact

For questions or bug reports about LLM Bridge, please send an email to rtlink.park@gmail.com.

## Contributing

This project is open source and welcomes contributions. Help improve the project through bug reports, feature requests, and pull requests.

## Changelog

For detailed changes, see [changelog.md](changelog.md).

---

**LLM Bridge** - Multi-platform client bridging various LLMs 