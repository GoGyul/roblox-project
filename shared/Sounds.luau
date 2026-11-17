-- 🔊 효과음과 배경음악 (클라이언트에서 사용)
--
-- 효과음은 로블록스 앱에 기본으로 들어 있는 소리(rbxasset://)를 써서 따로 올릴 필요가 없어요.
-- 배경음악은 로블록스 크리에이터 스토어에서 마음에 드는 음악을 골라 ID를 넣으면 돼요.
--   1. 스튜디오 Toolbox(또는 create.roblox.com/store/audio)에서 음악 검색
--   2. 음악의 ID 숫자를 복사
--   3. 아래 BGM 칸에 "rbxassetid://숫자" 형태로 입력 (비워 두면 음악 없음)

local SoundService = game:GetService("SoundService")

local Sounds = {}

Sounds.IDS = {
	click = "rbxasset://sounds/button.wav", -- 버튼 누름
	ping = "rbxasset://sounds/electronicpingshort.wav", -- 보너스, 알림
	caught = "rbxasset://sounds/uuhhh.mp3", -- 적발! (으악)
	crunch = "rbxasset://sounds/snap.wav", -- 간식 바삭
	swoosh = "rbxasset://sounds/swoosh.wav", -- 명세서, 창 열기
	bass = "rbxasset://sounds/bass.wav", -- 점심 끝, 해고
	typing = "rbxasset://sounds/clickfast.wav", -- 타자 치는 소리 (일하기 중 반복)
}

-- 🎵 배경음악: 예) "rbxassetid://1234567890"
Sounds.BGM = ""
Sounds.BGM_VOLUME = 0.25

local cache: { [string]: Sound } = {}

local function getSound(name: string): Sound?
	local id = Sounds.IDS[name]
	if not id or id == "" then
		return nil
	end
	local sound = cache[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = `Sfx_{name}`
		sound.SoundId = id
		sound.Parent = SoundService
		cache[name] = sound
	end
	return sound
end

-- 한 번 재생 (겹쳐서 재생돼요)
function Sounds.play(name: string, volume: number?, pitch: number?)
	local template = getSound(name)
	if not template then
		return
	end
	local sound = template:Clone()
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(10, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- 반복 재생용 소리 만들기 (켜고 끄는 건 받은 쪽에서: sound.Playing = true/false)
function Sounds.loop(name: string, volume: number?, pitch: number?): Sound?
	local id = Sounds.IDS[name]
	if not id or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = `Loop_{name}`
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = volume or 0.3
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	return sound
end

-- 배경음악 시작 (BGM이 비어 있으면 아무것도 안 해요)
function Sounds.startMusic()
	if Sounds.BGM == "" then
		return
	end
	local music = Instance.new("Sound")
	music.Name = "BackgroundMusic"
	music.SoundId = Sounds.BGM
	music.Looped = true
	music.Volume = Sounds.BGM_VOLUME
	music.Parent = SoundService
	music:Play()
end

return Sounds
