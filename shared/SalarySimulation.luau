-- Opt-in via salary.simulation.project.json only; never active in published servers.
local S = { protocol = "v5-split-telemetry", seed = 20261125, rank = 2, company = "nunchi", playerType = "normal", days = 5,
	strategies = { "normal", "cautious", "greedy", "novice", "normal" } }
function S.enabled(): boolean
	return game:GetService("RunService"):IsStudio() and workspace:GetAttribute("SalarySimulation") == true
end
S.scenario = workspace:GetAttribute("SalarySimulationScenario") or "natural"
S.workshopCase = workspace:GetAttribute("SalarySimulationWorkshopCase") or "timeout"
if S.enabled() then
	local strategy = workspace:GetAttribute("SalarySimulationStrategy")
	if strategy == "normal" or strategy == "cautious" or strategy == "greedy" or strategy == "novice" then
		S.playerType = strategy
		S.strategies = table.create(S.days, strategy)
	end
end
return S
