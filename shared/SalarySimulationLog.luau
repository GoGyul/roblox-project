-- Measurement-only transport. Keep every physical Output line below 900 bytes.
local Http = game:GetService("HttpService")
local S = require(script.Parent.SalarySimulation)
local Log = {}
function Log.write(fields)
	if not S.enabled() then return end
	local encoded = Http:JSONEncode(fields)
	if #encoded <= 800 then
		print("SALARY_SIM " .. encoded)
		return
	end
	local id = Http:GenerateGUID(false)
	local count = math.ceil(#encoded / 240)
	for index = 1, count do
		-- Hex preserves UTF-8 even when a chunk boundary splits a Korean character.
		local bytes = string.sub(encoded, (index - 1) * 240 + 1, index * 240)
		local payload = string.gsub(bytes, ".", function(byte) return string.format("%02x", string.byte(byte)) end)
		print("SALARY_SIM " .. Http:JSONEncode({kind = "log_chunk", id = id,
			index = index, count = count, bytes = #encoded, payload = payload}))
	end
end
return Log
