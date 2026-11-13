-- 고결게임즈 메인 광장 서버 시작점: 광장을 짓고, 포탈마다 출발 대기열을 켭니다.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 통신 채널 (클라이언트가 찾을 수 있게 가장 먼저 만들어요)
local remoteFolder = Instance.new("Folder")
remoteFolder.Name = "Remotes"
local function event(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remoteFolder
	return remote
end
local remotes = {
	Notify = event("Notify"), -- 서버 → 클라: 안내 문구
	Teleporting = event("Teleporting"), -- 서버 → 클라: 이동 시작 (로딩 화면 켜기)
	TeleportFailed = event("TeleportFailed"), -- 서버 → 클라: 이동 실패 (로딩 화면 끄기)
}
remoteFolder.Parent = ReplicatedStorage

local LobbyBuilder = require(script.LobbyBuilder)
local Queue = require(script.Queue)

-- 밝은 낮 분위기
Lighting.ClockTime = 14
Lighting.Ambient = Color3.fromRGB(110, 110, 120)
Lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 140)

local portals = LobbyBuilder.build()
Queue.setup(remotes)
for _, portal in portals do
	Queue.new(portal.pad, portal.statusLabel, portal.game)
end

print(`🏛️ 고결게임즈 메인 광장 준비 완료! (게임 {#portals}개)`)
