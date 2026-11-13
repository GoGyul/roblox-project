# 고결게임즈

[Rojo](https://rojo.space)로 코드를 관리하는 로블록스 게임 모음이에요.
**메인 광장**에 게임별 포탈이 있고, 포탈 앞 발판에서 팀을 모아 출발하면 그 게임의 **팀 전용 서버**로 이동해요.
광장에는 앞으로 게임이 하나씩 추가될 예정이에요.

### 지금 있는 게임
- 🕰️ **멈춘 시계탑** (방탈출): 회중시계로 **현재 ↔ 50년 전 과거**를 오가며 퍼즐을 풀고, 멈춘 시계탑을 다시 움직이면 탈출해요.

### 새 게임 추가하는 법
1. `places/새게임/` 폴더(server, client)와 `새게임.project.json`을 만들어요. 기존 것을 복사하면 쉬워요.
2. 로블록스 Experience에 **새 Place를 추가하고 Publish**해요.
3. `shared/Places.luau`의 `Games` 목록에 게임 정보(이름, 이모지, Place ID, 인원, 색)를 추가해요.
4. 광장을 다시 Publish하면 **포탈이 자동으로 생겨요.** (포탈 자리는 현재 3개)

> 연습용으로 만든 오비 게임은 `main` 브랜치의 첫 커밋에 남아 있어요.

## 처음 한 번만: 준비하기

1. **Roblox Studio** 설치
2. **Rojo 7.7.1** 설치 (팀원 모두 같은 버전을 써 주세요)
   - [Rojo 릴리스 페이지](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1)에서 내 컴퓨터에 맞는 파일을 받아요.
     - Apple Silicon 맥: `macos-aarch64`
     - Intel 맥: `macos-x86_64`
     - 윈도우: `windows-x86_64`
   - 압축을 풀고 `rojo` 파일을 PATH에 있는 폴더에 넣어요. 예: 맥은 `~/.local/bin`
   - 터미널에서 `rojo --version`을 쳤을 때 `Rojo 7.7.1`이 나오면 성공이에요.
3. **스튜디오 플러그인 설치**

   ```bash
   rojo plugin install
   ```

4. **저장소 받기**

   ```bash
   git clone https://github.com/GoGyul/roblox-project.git
   cd roblox-project
   ```

## 개발하기

1. 프로젝트 폴더에서 **작업할 장소**의 동기화 서버를 켜요. (한 번에 하나만)

   ```bash
   rojo serve lobby.project.json        # 메인 광장 작업할 때
   rojo serve clocktower.project.json   # 시계탑 방탈출 작업할 때
   ```

2. 스튜디오에서 **Baseplate** 템플릿으로 새 장소를 만들어요. 이 장소는 각자 테스트용이에요.
3. **Plugins → Rojo → Connect**를 눌러요.
4. 이제 `src/`의 코드를 고치면 스튜디오에 바로 반영돼요. **▶ Play**로 테스트하세요.

> ⚠️ 여러 명이 같은 Team Create 장소에 동시에 Rojo로 연결하지 마세요. 서로 덮어써요.
> 테스트는 각자 자기 장소에서 하세요.

## 폴더 구조

이 게임은 **장소(Place) 두 개**로 이루어져 있어요. 광장에서 시계탑으로는 텔레포트로 이동해요.

```
lobby.project.json        ← 🏛️ 고결게임즈 메인 광장 장소의 Rojo 설정
clocktower.project.json   ← 🕰️ 시계탑 장소의 Rojo 설정
places/
├── lobby/                ← 메인 광장 전용 코드
│   ├── server/  (init.server, LobbyBuilder, Queue)
│   └── client/  (init.client)
└── clocktower/           ← 시계탑 방탈출 전용 코드
    ├── server/  (init.server, TowerBuilder, Puzzles, TimeTravel, Inventory, Remotes)
    └── client/  (init.client, Hud, Panels)
shared/                   ← 두 장소가 함께 쓰는 코드 (ReplicatedStorage.Shared)
    Places.luau     게임 목록 + 장소 ID ← Publish 후 꼭 채우기!
    Teleport.luau   장소 이동
    Build.luau      맵 짓는 도구
    Ui.luau         UI 도우미
    Config.luau     시계탑 설정
```

| 파일 이름 | 스튜디오에서 |
| --- | --- |
| `init.server.luau` | Script (서버에서 자동 실행) |
| `init.client.luau` | LocalScript (클라이언트에서 자동 실행) |
| 그 외 `.luau` | ModuleScript (`require`로 불러서 사용) |

> 스튜디오 테스트에서는 텔레포트가 동작하지 않아요. 장소 이동은 Publish한 게임에서 확인하세요.
> 스튜디오에서 손으로 만든 파트나 모델은 Git에 저장되지 않아요. 맵은 코드로 만들어 주세요.

## 협업 규칙

1. 작업을 시작하기 전에 최신 코드를 받아요: `git checkout main && git pull`
2. 기능마다 브랜치를 만들어요: `git checkout -b feature/새-스테이지`
3. 작업하고 커밋한 뒤 브랜치를 올려요: `git push -u origin feature/새-스테이지`
4. GitHub에서 **Pull Request**를 만들고, 리뷰를 받은 뒤 `main`에 합쳐요.
5. 실제 게임에 올리는 건(Publish) 정해진 한 사람이 `main` 기준으로 해요.
