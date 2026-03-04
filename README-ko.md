# ✨ LLM Bridge - Multi LLM Client ✨

_Multi-platform LLM client supporting Ollama, LM Studio, Claude, and OpenAI_

[한국어](README-ko.md) • [English](README.md) • [日本語](README-jp.md) • [中文](README-cn.md)

# LLM Bridge

LLM Bridge는 Ollama, LM Studio, Claude, OpenAI 등 다양한 LLM 서비스에 연결할 수 있는 멀티 플랫폼 클라이언트 앱입니다. 소스 코드를 다운로드하여 빌드하거나 App Store에서 LLM Bridge 앱을 다운로드할 수 있습니다.

## 소개

LLM Bridge는 다양한 LLM 플랫폼을 지원하는 다재다능한 클라이언트입니다:

* **Ollama**: 로컬에서 LLM을 실행하기 위한 오픈소스 소프트웨어
* **LM Studio**: 다양한 모델을 지원하는 로컬 LLM 플랫폼
* **Claude**: Anthropic의 고급 AI 모델
* **OpenAI**: GPT-5를 포함한 GPT 모델의 선도적인 AI 플랫폼

## 주요 기능

* **다중 LLM 플랫폼 지원**:
  * Ollama를 통한 로컬 LLM 접근 (`http://localhost:11434`)
  * LM Studio 통합 (`http://localhost:1234`)
  * Claude API 지원 - API Key 필요
  * OpenAI API 지원 - API Key 필요
* **선택적 서비스 표시**: 모델 선택 메뉴에서 표시할 LLM 서비스를 선택
* **원격 LLM 접근**: IP 주소를 통해 Ollama/LM Studio 호스트에 연결
* **커스텀 프롬프트**: 커스텀 지침 설정 지원
* **다양한 오픈소스 LLM 지원** (Deepseek, Llama, Gemma, Qwen, Mistral 등)
* **GPT-5 지원**: OpenAI GPT-5 모델 지원 및 자동 비스트리밍 폴백
* **커스터마이징 가능한 지침 설정**
* **고급 모델 매개변수**: 직관적인 슬라이더로 Temperature, Top P, Top K 제어
* **연결 테스트**: 내장된 서버 연결 상태 확인기
* **다중 형식 파일 지원**: 이미지, PDF 문서, 텍스트 파일
* **이미지 인식 지원** (지원하는 모델에서만)
* **개선된 채팅 UI**: 사용자/어시스턴트 아바타 아이콘, 새로운 메시지 버블 디자인
* **네이티브 Picker 모델 선택**: macOS/iOS 네이티브 Picker를 사용한 향상된 프로바이더 및 모델 선택
* **직관적인 채팅형 UI**
* **대화 기록**: 채팅 세션 저장 및 관리
* **한국어, 영어, 일본어, 중국어 지원**
* **Markdown 형식 지원**

## 플랫폼별 지원

### 🖥️ macOS 지원

macOS용 LLM Bridge는 네이티브 macOS 앱으로 개발되어 데스크톱 환경에 최적화되어 있습니다.

#### macOS 주요 특징:
- **로컬 LLM**: 로컬 LLM 연결
- **네이티브 macOS UI**: macOS 디자인 가이드라인을 따르는 인터페이스
- **사이드바 네비게이션**: 대화 목록과 메인 채팅 영역을 분리한 효율적인 레이아웃
- **모델 선택 메뉴**: 상단 툴바에서 쉽게 모델을 선택하고 변경
- **고급 설정**: 상세한 LLM 매개변수 조정 및 서버 설정
- **파일 드래그 앤 드롭**: 이미지와 문서를 쉽게 업로드
- **키보드 단축키**: 생산성을 높이는 단축키 지원

![macOS 메인 화면](mac.jpg)

![macOS 설정 화면](mac_settings.jpg)

### 📱 iOS 지원

iOS용 LLM Bridge는 모바일 환경에 최적화된 인터페이스를 제공합니다.

#### iOS 주요 특징:
- **로컬 LLM**: 로컬 LLM 연결
- **모바일 최적화 UI**: 터치 인터페이스에 최적화된 디자인
- **탭 기반 네비게이션**: 직관적인 탭 구조로 쉬운 탐색
- **스와이프 제스처**: 메시지 삭제 및 관리
- **카메라 통합**: 사진 촬영 및 이미지 분석


#### iOS 스크린샷 갤러리

<div style="display: flex; flex-wrap: wrap; gap: 10px;">
  <img src="iphone10.png" width="200" alt="iOS 화면 10">
  <img src="iphone01.png" width="200" alt="iOS 화면 1">
  <img src="iphone02.png" width="200" alt="iOS 화면 2">
  <img src="iphone03.png" width="200" alt="iOS 화면 3">
  <img src="iphone04.png" width="200" alt="iOS 화면 4">
  <img src="iphone05.png" width="200" alt="iOS 화면 5">
  <img src="iphone06.png" width="200" alt="iOS 화면 6">
  <img src="iphone07.png" width="200" alt="iOS 화면 7">
  <img src="iphone08.png" width="200" alt="iOS 화면 8">
  <img src="iphone09.png" width="200" alt="iOS 화면 9">
  <img src="iphone11.png" width="200" alt="iOS 화면 11">
</div>

## 사용 방법

### 1. 선호하는 LLM 플랫폼 선택:
* **Ollama**: 컴퓨터에 Ollama 설치 ([Ollama 다운로드](https://ollama.com/download))
* **LM Studio**: LM Studio 설치 ([LM Studio 웹사이트](https://lmstudio.ai))
* **Claude/OpenAI**: 각 플랫폼에서 API 키 획득

### 2. 앱 다운로드:
* 소스를 다운로드하여 Xcode로 빌드하거나
* App Store에서 LLM Bridge 앱 다운로드

### 3. 선택한 플랫폼 구성:
* **Ollama/LM Studio**: 원하는 모델 설치
* **Claude/OpenAI**: 설정에서 API 키 입력

### 4. 로컬 LLM (Ollama/LM Studio)의 경우:
* 필요시 원격 접근 구성

### 5. LLM Bridge 실행:
* 선호하는 서비스와 모델 선택
* 대화 시작!

## 시스템 요구사항

### macOS 요구사항:
- macOS 12.0 (Monterey) 이상
- 로컬 LLM: Ollama 또는 LM Studio가 설치된 컴퓨터
- 클라우드 LLM: Claude 또는 OpenAI의 유효한 API 키
- 네트워크 연결

### iOS 요구사항:
- iOS 15.0 이상
- 로컬 LLM: Ollama 또는 LM Studio가 설치된 네트워크 내 컴퓨터
- 클라우드 LLM: Claude 또는 OpenAI의 유효한 API 키
- Wi-Fi 또는 셀룰러 연결

## 장점

* **로컬 및 클라우드 기반 LLM 모두 지원**
* **스트리밍 인터페이스를 위한 유연한 서비스 선택**
* **다양한 플랫폼을 통한 고급 AI 기능**
* **개인정보 보호 옵션 (로컬 LLM)**
* **프로그래밍, 창작 작업, 일반적인 질문 등 다양한 용도**
* **체계적인 대화 관리**

## 기술적 특징

### 아키텍처
- **SwiftUI**: 현대적인 선언적 UI 프레임워크 사용
- **Combine**: 반응형 프로그래밍을 위한 프레임워크
- **Async/Await**: 비동기 작업 처리
- **Core Data**: 로컬 데이터 저장 및 관리

### 네트워킹
- **URLSession**: 효율적인 HTTP 통신
- **Server-Sent Events**: 실시간 스트리밍 응답
- **JSON**: 표준 데이터 교환 형식
- **Base64**: 이미지 인코딩

### 보안
- **HTTPS**: 안전한 통신
- **API 키 관리**: 안전한 인증 정보 저장
- **로컬 처리**: 개인정보 보호를 위한 로컬 LLM 지원

## 주의사항

* 로컬 LLM 기능은 Ollama 또는 LM Studio 설치가 필요합니다
* Claude 및 OpenAI 서비스에는 API 키가 필요합니다
* 로컬 LLM 호스트와 API 키를 안전하게 관리하는 것은 사용자의 책임입니다

## 앱 다운로드

빌드에 어려움이 있는 경우 아래 링크에서 앱을 다운로드할 수 있습니다.

* **macOS**: [Mac App Store](https://apps.apple.com/us/app/mac-ollama-client/id6741420139)
* **iOS**: [App Store](https://apps.apple.com/us/app/llm-bridge-multi-llm-client/id6738298481?platform=iphone)

## 라이선스

LLM Bridge는 GNU 라이선스 하에 제공됩니다. 자세한 내용은 LICENSE 파일을 참조하세요.

## 문의

LLM Bridge에 대한 질문이나 버그 리포트는 rtlink.park@gmail.com으로 이메일을 보내주세요.

## 기여

이 프로젝트는 오픈소스이며 기여를 환영합니다. 버그 리포트, 기능 요청, 풀 리퀘스트를 통해 프로젝트 발전에 도움을 주세요.

## 변경 이력

자세한 변경 사항은 [changelog.md](changelog.md)를 참조하세요.

---

**LLM Bridge** - 다양한 LLM과의 다리 역할을 하는 멀티 플랫폼 클라이언트 