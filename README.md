# TokenNotch

맥북 노치 옆에서 **Clawd(클로드의 게 마스코트)** 와 **Codex 로봇**이 살면서
Claude Code / Codex CLI의 남은 사용량과 세션 리셋 시간을 알려주는 위젯.

- **노치 왼쪽**: 🦀 Clawd — Claude Code CLI에 실제 내장된 공식 픽셀 스프라이트(쿼드런트 블록 아트,
  `clawd_body` 색상 rgb(215,119,87), 포즈: standing/look-left/look-right/arms-up)를 1:1 재현.
  옆걸음으로 순찰하며 남은 % 표시
- **노치 오른쪽**: 🤖 Codex — Codex CLI의 공식 대표 펫("The original Codex companion",
  구름 머리에 터미널 얼굴 `>_`)을 사용. 스프라이트시트는 저장소에 포함하지 않고
  Codex CLI와 동일하게 OpenAI CDN에서 실행 시 다운로드해 캐시(`~/Library/Caches/NotchUsage/`).
  여유=달리기, 걱정=노트북 타이핑, 위험=슬픔(x_x), 오류=잠들기
- **캐릭터 상태**: 여유(>50%) 느긋한 걸음 → 걱정(20~50%) 땀 흘리며 종종걸음 →
  위험(<20%) 부들부들 → 오류·토큰 만료 시 잠들어서 zzz
- **마우스를 올리면 확장**: 두 서비스 각각의 5시간 세션 / 주간 한도 진행 바, 리셋 시각과 카운트다운, 종료 버튼

컨셉 참고: [CodexIsland](https://github.com/ericjypark/codex-island) (폴링 정책도 여기서 배움)

## 동작 방식

5분마다 공식 사용량 수치를 조회합니다 (Claude usage 엔드포인트는 CLI User-Agent가
아니거나 폴링이 잦으면 sticky 429를 반환하므로, 5분 주기 + 429 시 15분 쿨다운):

| | 인증 | 엔드포인트 |
|---|---|---|
| Claude Code | macOS 키체인 `Claude Code-credentials`의 OAuth 토큰 | `api.anthropic.com/api/oauth/usage` |
| Codex CLI | `~/.codex/auth.json`의 access_token + account_id | `chatgpt.com/backend-api/wham/usage` |

Claude 쪽은 `/usage` 명령과, Codex 쪽은 `/status` 명령과 같은 수치입니다.

토큰 갱신은 하지 않습니다 — 만료되면 위젯에 안내가 뜨고, 해당 CLI를 한 번 실행하면
자동으로 갱신됩니다. (Codex의 리프레시 토큰은 일회용이라 위젯이 직접 갱신하면
CLI 로그인이 깨질 수 있어 의도적으로 읽기 전용입니다.)

UI는 [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) (MIT)의 컴팩트 모드를 사용합니다.

## 빌드 & 실행

```bash
swift build && .build/debug/NotchUsage      # 개발 실행
./install.sh                                 # dist/NotchUsage.app 생성
./install.sh --autostart                     # + 로그인 시 자동 실행 등록
```

요구 사항: 노치 있는 MacBook, macOS 14+, Xcode 커맨드라인 툴, Claude Code / Codex CLI 로그인 상태.

## 종료

확장 뷰(호버) 우측 상단의 전원 버튼, 또는 `pkill -x NotchUsage`.

자동 실행 해제:

```bash
launchctl unload ~/Library/LaunchAgents/local.notchusage.plist
rm ~/Library/LaunchAgents/local.notchusage.plist
```

## 파일 구성

- `Sources/NotchUsage/main.swift` — 앱 진입점 (Dock 아이콘 없는 accessory 앱)
- `Sources/NotchUsage/AppDelegate.swift` — DynamicNotch 생성, 호버 시 확장/축소, 60초 폴링 루프
- `Sources/NotchUsage/UsageModel.swift` — Claude 키체인/Codex auth.json 읽기, usage API 호출, 상태 모델
- `Sources/NotchUsage/Characters.swift` — Clawd 스프라이트 렌더러 + 폴백 로봇
- `Sources/NotchUsage/CodexPet.swift` — 공식 Codex 펫 스프라이트시트 로더/애니메이터
- `Sources/NotchUsage/Views.swift` — 컴팩트/확장 SwiftUI 뷰
