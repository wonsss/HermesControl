# Hermes Control

[English](README.md) | **한국어**

[Hermes Agent](https://hermes-agent.nousresearch.com)를 위한 macOS 메뉴 막대 앱입니다. Hermes 메시징 게이트웨이를 켜고 끄고, 실시간 요청을 확인하고, 모델의 추론 과정을 보고, 모델을 전환하는 작업을 터미널 없이 처리할 수 있습니다.

[![build](https://github.com/wonsss/HermesControl/actions/workflows/build.yml/badge.svg)](https://github.com/wonsss/HermesControl/actions/workflows/build.yml)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Hermes Agent](https://img.shields.io/badge/Hermes-Agent-required-orange)
![Swift 6](https://img.shields.io/badge/Swift-6-red)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## 목차

- [주요 기능](#주요-기능)
- [요구 사항](#요구-사항)
- [설치 방법](#설치-방법)
- [사용 방법](#사용-방법)
- [동작 방식](#동작-방식)
- [노타라이즈](#노타라이즈)
- [보안](#보안)
- [라이선스](#라이선스)

## 주요 기능

- **게이트웨이 제어** — 메뉴 막대에서 Hermes 메시징 게이트웨이를 켜고 끌 수 있습니다
- **영구 해제 상태 유지** — OFF로 바꾸면 Hermes launch agent의 `RunAtLoad`를 수정해 재로그인 후에도 꺼진 상태를 유지합니다
- **실시간 요청 추적** — 현재 들어온 요청의 플랫폼, 발신자, 메시지, 경과 시간을 바로 볼 수 있습니다
- **Thinking 창** — 활성 요청의 추론 과정과 대화 내용을 별도 창에서 실시간으로 볼 수 있습니다
- **최근 활동** — 완료되거나 취소된 최근 세션을 팝오버에서 다시 확인할 수 있습니다
- **강제 취소** — 팝오버와 Thinking 창에서 현재 Hermes 세션을 강제로 중단할 수 있습니다
- **토큰 / 비용 표시** — 입력, 출력, reasoning 토큰과 추정 비용을 확인할 수 있습니다
- **모델 전환** — Hermes 설정에 등록된 모델을 전환하면 게이트웨이가 자동으로 재시작됩니다
- **알림** — 새 요청이 들어오면 macOS 알림을 받을 수 있습니다
- **/Applications 이동 안내** — 다른 위치에서 실행하면 첫 실행 시 `/Applications`로 옮길지 묻습니다

## 요구 사항

| 항목 | 상세 |
|---|---|
| macOS | 14.0 (Sonoma) 이상 |
| Hermes Agent | 로컬에 설치 및 설정 완료 |
| Hermes 홈 | 기본값 `~/.hermes`, 또는 `HERMES_HOME`으로 사용자 지정 |
| Hermes CLI | PATH 또는 Hermes 기본 설치 위치에서 `hermes` 실행 가능 |

Hermes Control은 Hermes의 로컬 상태 DB와 설정 파일을 읽고 Hermes 게이트웨이 프로세스를 제어합니다. Hermes Agent가 설치되어 있지 않으면 앱이 관리할 대상이 없습니다.

## 설치 방법

### 방법 A — 노타라이즈된 앱 다운로드 (권장)

1. [Releases](https://github.com/wonsss/HermesControl/releases) 페이지를 엽니다
2. 최신 `HermesControl-x.y.z.dmg`를 다운로드합니다
3. DMG를 열고 `HermesControl.app`을 `/Applications`로 드래그합니다
4. `HermesControl.app`을 실행합니다

ZIP 형식을 원하면 같은 릴리즈 페이지의 `HermesControl-notarized.zip`도 사용할 수 있습니다.

### 방법 B — 소스에서 직접 빌드

```bash
git clone https://github.com/wonsss/HermesControl.git
cd HermesControl
./build.sh
open HermesControl.app
```

빌드한 앱을 `/Applications`에 두고 싶다면 한 번 실행한 뒤 표시되는 이동/설치 안내를 수락하면 됩니다.

Xcode Command Line Tools가 필요합니다:

```bash
xcode-select --install
```

### Gatekeeper

GitHub Release의 DMG는 노타라이즈되어 있어 일반적으로 바로 실행됩니다.

로컬 빌드본이 첫 실행에서 막히면, 앱을 우클릭해서 **Open**을 선택하거나 아래 명령으로 quarantine 플래그를 제거하면 됩니다.

```bash
xattr -dr com.apple.quarantine HermesControl.app
```

## 사용 방법

1. [Hermes Agent](https://hermes-agent.nousresearch.com)를 설치하고 설정합니다
2. `HermesControl.app`을 실행합니다
3. 메뉴 막대 항목을 클릭해 상태 팝오버를 엽니다
4. **Connect** / **Disconnect**로 Hermes 게이트웨이를 제어합니다
5. 활성 요청이나 최근 요청을 클릭해 Thinking 창을 엽니다
6. 현재 세션을 멈춰야 하면 강제 취소 버튼을 누릅니다
7. 필요할 때 내장 모델 목록에서 모델을 전환합니다

## 동작 방식

- Hermes Control은 Hermes의 로컬 게이트웨이 로그와 상태 DB를 모니터링합니다
- Hermes 설정 파일에서 모델 목록을 읽고 현재 활성 모델을 표시합니다
- Hermes SQLite 상태 DB에서 세션 메타데이터를 읽어 추론, 대화, 토큰 사용량, 비용을 표시합니다
- 모델 전환이나 강제 취소가 필요할 때 Hermes 게이트웨이를 재시작합니다

## 노타라이즈

Apple Developer Program 멤버십과 `Developer ID Application` 인증서가 있는 유지보수자를 위한 절차입니다:

```bash
./notarize.sh --store-credentials
./notarize.sh
```

이 명령은 앱을 빌드하고, 서명하고, Apple 노타라이즈를 제출하고, 스테이플링한 뒤 `HermesControl-notarized.zip`을 생성합니다.

## 보안

- **비신뢰 입력에 셸 문자열 보간 없음** — 서브프로세스는 명시적인 인자 배열을 사용합니다
- **모델 / 설정 검증** — 모델 ID, provider, base URL을 설정 파일에 쓰기 전에 검증합니다
- **도구 자동 탐색** — 사용자 경로 하드코딩 대신 PATH와 공통 설치 위치에서 Hermes 바이너리를 찾습니다
- **로컬 제어 중심** — 앱은 Hermes 로컬 상태를 읽고 제어하며 자체 외부 네트워크 서비스를 추가하지 않습니다

## 라이선스

MIT — [LICENSE](LICENSE) 참고
