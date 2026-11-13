-- 서버 ↔ 클라이언트 통신 채널을 만들어요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function event(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local submitCode = Instance.new("RemoteFunction")
submitCode.Name = "SubmitCode"
submitCode.Parent = folder

local Remotes = {
	Notify = event("Notify"), -- 서버 → 클라: 화면 아래 안내 문구
	ShowNote = event("ShowNote"), -- 서버 → 클라: 쪽지/일기 읽기 창
	OpenCodeLock = event("OpenCodeLock"), -- 서버 → 클라: 비밀번호 입력 창 열기
	ToggleEra = event("ToggleEra"), -- 클라 → 서버: 시간 전환 요청
	Escaped = event("Escaped"), -- 서버 → 클라: 탈출 성공
	ReturnToLobby = event("ReturnToLobby"), -- 클라 → 서버: 광장으로 돌아가기
	SubmitCode = submitCode, -- 클라 → 서버: 비밀번호 제출 (정답 확인은 서버만)
}

folder.Parent = ReplicatedStorage

return Remotes
