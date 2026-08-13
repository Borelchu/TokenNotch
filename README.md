# TokenNotch

한국어 | [English](README.en.md)

<p align="center">
  <img src="docs/hero.png" width="100%" alt="MacBook 노치 주변의 픽셀 캐릭터와 사용량 패널을 표현한 TokenNotch 히어로 이미지">
</p>

맥북 노치 옆에서 **Clawd(Claude Code 공식 픽셀 게)** 와 **Codex 펫(Codex CLI 공식 컴패니언)** 이 살면서
Claude Code / Codex CLI의 남은 사용량과 세션 리셋 시간을 알려주는 위젯입니다.

<p align="center">
  <img src="docs/notchdemo.gif" width="760" alt="TokenNotch 데모 — 노치 옆 캐릭터, 호버 시 확장 패널, 표시 토글">
</p>

<p align="center">
  <img src="docs/expanded.gif" width="330" alt="확장 화면 자세히 — 서비스별 카드, HP바, 리셋 카운트다운">
</p>

- 🦀 **노치 왼쪽 — Clawd**: Claude Code CLI에 실제 내장된 공식 스프라이트(쿼드런트 블록 아트,
  `clawd_body` 색상 rgb(215,119,87), 포즈 4종)를 1:1 재현. 옆걸음으로 순찰하며 남은 % 표시
- 🤖 **노치 오른쪽 — Codex 펫**: Codex CLI의 공식 대표 펫 "The original Codex companion".
  스프라이트시트는 저장소에 포함하지 않고 Codex CLI와 동일하게 OpenAI CDN에서 실행 시 다운로드해 캐시

---

## 1. 요구 사항

| 항목 | 조건 |
|---|---|
| 하드웨어 | 노치가 있는 MacBook (Pro/Air 2021 이후) |
| OS | macOS 14 (Sonoma) 이상 |
| 빌드 도구 | Xcode 또는 Xcode Command Line Tools (`xcode-select --install`) |
| Claude 데이터 | Claude Code 로그인 상태 (Pro/Max 구독) |
| Codex 데이터 (선택) | Codex CLI 로그인 상태 (ChatGPT Plus/Pro) |

> 한쪽만 써도 됩니다. 안 쓰는 쪽은 위젯에서 끌 수 있어요 (아래 [표시 토글](#4-표시-토글) 참고).

## 2. 설치 & 실행

```bash
git clone https://github.com/Borelchu/TokenNotch.git
cd TokenNotch

# 방법 A) 앱으로 설치 (권장)
./install.sh                 # 빌드 후 dist/NotchUsage.app 생성
open dist/NotchUsage.app     # 실행 — 노치 양옆에 캐릭터가 나타남

# 방법 B) 로그인 시 자동 실행까지 등록
./install.sh --autostart

# 방법 C) 개발용으로 바로 실행
swift build && .build/debug/NotchUsage
```

첫 실행 시 하는 일:
- 키체인의 Claude Code 자격 증명을 읽습니다 (권한 대화상자가 뜨면 **"항상 허용"**)
- Codex 펫 스프라이트시트를 OpenAI CDN에서 내려받아 `~/Library/Caches/NotchUsage/`에 캐시합니다
- 이후 5분마다 두 서비스의 공식 사용량 API를 조회합니다

Dock 아이콘과 메뉴바 아이콘은 없습니다. 오직 노치 옆에만 삽니다.

UI 언어는 macOS 시스템 언어를 따라갑니다 (한국어 / 영어).

## 3. 화면 읽는 법

### 컴팩트 (항상 표시)

```
  🦀 72%     [ 노치 ]     96% 🤖
```

- 숫자 = **5시간 세션 기준 남은 양** (Codex가 주간 한도만 있는 요금제면 주간 기준)
- 색상 = 초록(50% 초과) / 노랑(20~50%) / 빨강(20% 미만)
- 캐릭터 행동으로도 상태를 알 수 있습니다:

| 남은 양 | Clawd | Codex 펫 |
|---|---|---|
| 50% 초과 | 느긋한 옆걸음 순찰, 반환점에서 만세 | 신나게 달리기 |
| 20~50% | 땀 흘리며 종종걸음 | 노트북 펴고 열심히 타이핑 + 땀 |
| 20% 미만 | 만세 자세로 패닉, 부들부들 | 슬픈 표정(x_x), 부들부들 |
| 오류/토큰 만료 | 잠들어서 zzz | 잠들어서 zzz |

### 확장 뷰 (노치에 마우스 올리면)

- 서비스별 카드에 **HP바**(채워진 만큼이 남은 양)와 남은 % 배지
- ⏰ 리셋 시각 + 카운트다운 (예: `17:59 리셋 · 2시간 12분 후`)
- Claude는 5시간 세션/주간(전체·Opus·Sonnet), Codex는 요금제가 제공하는 창(세션/주간)을 표시
- 캐릭터 말풍선: "아직 든든해요!" → "아껴 써야 해요…" → "거의 다 썼어요!!" → "쉬는 중… zzz"
- 우측 상단 ⏻ 버튼 = 앱 종료

## 4. 표시 토글

확장 뷰 헤더 오른쪽의 **캐릭터 얼굴 칩**을 클릭하면 해당 서비스를 켜고 끕니다.

- 꺼진 서비스는 확장 뷰 카드와 노치 옆 컴팩트 표시 모두에서 사라집니다
- 꺼진 칩은 흑백으로 흐려집니다
- 설정은 자동 저장되어 재시작해도 유지됩니다 (`defaults` 도메인에 `showClaude`/`showCodex`)
- 둘 다 끌 수는 없습니다 — 마지막 하나를 끄면 반대쪽이 자동으로 켜집니다

## 5. 데이터를 어디서 가져오나

| | 인증 | 엔드포인트 | 수치의 의미 |
|---|---|---|---|
| Claude Code | macOS 키체인 `Claude Code-credentials`의 OAuth 토큰 | `api.anthropic.com/api/oauth/usage` | `/usage` 명령과 동일한 공식 수치 |
| Codex CLI | `~/.codex/auth.json`의 access_token + account_id | `chatgpt.com/backend-api/wham/usage` | `/status` 명령과 동일한 공식 수치 |

- **5분 주기 폴링**: Claude usage 엔드포인트는 CLI User-Agent가 아니거나 호출이 잦으면
  한 번 걸리면 ~10분 지속되는 sticky 429를 반환합니다. 그래서 5분 주기 + 429 시 15분 쿨다운을 씁니다.
- **토큰 갱신은 하지 않습니다**: 만료되면 카드에 안내가 뜨고, 해당 CLI(`claude` 또는 `codex`)를
  한 번 실행하면 자동으로 갱신됩니다. 특히 Codex의 리프레시 토큰은 일회용이라 위젯이 직접
  갱신하면 CLI 로그인이 깨질 수 있어 의도적으로 읽기 전용입니다.
- Codex의 세션/주간 창은 위치가 아니라 `limit_window_seconds`로 판별합니다
  (Plus 요금제는 주간 창만 내려오는 경우가 있음).

## 6. 종료 / 제거

```bash
# 종료: 확장 뷰의 ⏻ 버튼, 또는
pkill -x NotchUsage

# 자동 실행 해제
launchctl unload ~/Library/LaunchAgents/local.notchusage.plist
rm ~/Library/LaunchAgents/local.notchusage.plist

# 완전 제거
rm -rf dist ~/Library/Caches/NotchUsage
```

## 7. 파일 구성

- `Sources/NotchUsage/main.swift` — 앱 진입점 (Dock 아이콘 없는 accessory 앱)
- `Sources/NotchUsage/AppDelegate.swift` — DynamicNotch 생성, 호버 시 확장/축소, 5분 폴링 루프
- `Sources/NotchUsage/UsageModel.swift` — Claude 키체인/Codex auth.json 읽기, usage API 호출, 상태 모델
- `Sources/NotchUsage/Characters.swift` — 공식 Clawd 스프라이트 렌더러 (+ Codex 폴백 로봇)
- `Sources/NotchUsage/CodexPet.swift` — 공식 Codex 펫 스프라이트시트 로더/애니메이터
- `Sources/NotchUsage/L10n.swift` — 시스템 언어 기반 한국어/영어 문자열
- `Sources/NotchUsage/Views.swift` — 컴팩트/확장 SwiftUI 뷰, 표시 토글, HP바
- `install.sh` — 릴리스 빌드 → .app 번들 생성 (+ `--autostart`로 LaunchAgent 등록)
