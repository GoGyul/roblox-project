# 로블록스 오비 프로젝트

[Rojo](https://rojo.space)로 코드를 관리하는 로블록스 오비(장애물 코스) 게임이에요.
코스, 게임 로직, UI가 전부 `src/` 안의 코드라서 Git으로 함께 작업할 수 있어요.

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

1. 프로젝트 폴더에서 동기화 서버를 켜요.

   ```bash
   rojo serve
   ```

2. 스튜디오에서 **Baseplate** 템플릿으로 새 장소를 만들어요. 이 장소는 각자 테스트용이에요.
3. **Plugins → Rojo → Connect**를 눌러요.
4. 이제 `src/`의 코드를 고치면 스튜디오에 바로 반영돼요. **▶ Play**로 테스트하세요.

> ⚠️ 여러 명이 같은 Team Create 장소에 동시에 Rojo로 연결하지 마세요. 서로 덮어써요.
> 테스트는 각자 자기 장소에서 하세요.

## 폴더 구조

| 경로 | 스튜디오 위치 | 역할 |
| --- | --- | --- |
| `src/server/init.server.luau` | ServerScriptService.Server | 서버 시작점 |
| `src/server/CourseBuilder.luau` | Server 안의 모듈 | 코스 만들기 (발판, 장애물) |
| `src/server/StageService.luau` | Server 안의 모듈 | 체크포인트, 죽는 발판, 골인 |
| `src/client/init.client.luau` | StarterPlayerScripts.Client | 화면 UI (스테이지, 타이머) |
| `src/shared/` | ReplicatedStorage.Shared | 서버와 클라이언트가 같이 쓰는 코드 |

> 스튜디오에서 손으로 만든 파트나 모델은 Git에 저장되지 않아요.
> 맵은 `CourseBuilder.luau`에 코드로 추가하거나, 모델을 `.rbxm`으로 저장해 `src/` 안에 넣어 주세요.

## 협업 규칙

1. 작업을 시작하기 전에 최신 코드를 받아요: `git checkout main && git pull`
2. 기능마다 브랜치를 만들어요: `git checkout -b feature/새-스테이지`
3. 작업하고 커밋한 뒤 브랜치를 올려요: `git push -u origin feature/새-스테이지`
4. GitHub에서 **Pull Request**를 만들고, 리뷰를 받은 뒤 `main`에 합쳐요.
5. 실제 게임에 올리는 건(Publish) 정해진 한 사람이 `main` 기준으로 해요.
