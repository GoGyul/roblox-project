-- 서버 ↔ 클라이언트 통신 채널

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function event(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local function func(name: string): RemoteFunction
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local Remotes = {
	SetAction = event("SetAction"), -- 클라 → 서버: 자리에서 할 행동 고르기 (일하기/멍때리기/...)
	ReturnToLobby = event("ReturnToLobby"), -- 클라 → 서버: 광장으로
	UseEnergy = event("UseEnergy"), -- 클라 → 서버: 에너지 드링크 마시기
	BuyItem = func("BuyItem"), -- 클라 → 서버 → 답장: 매점에서 아이템 사기 (성공 여부, 메시지)
	Notify = event("Notify"), -- 서버 → 클라: 안내 문구
	NearMiss = event("NearMiss"), -- 서버 → 클라: 아슬아슬 보너스 (금액, 콤보)
	Caught = event("Caught"), -- 서버 → 클라: 적발! (부장 대사, 경고 수)
	Fired = event("Fired"), -- 서버 → 클라: 해고
	Payslip = event("Payslip"), -- 서버 → 클라: 월급명세서 (+ 승진 소식)
	Unlocked = event("Unlocked"), -- 서버 → 클라: 도감에 새 항목 (이모지, 이름)
}

folder.Parent = ReplicatedStorage

return Remotes
