local ServicesFolder = script.Parent
local StorageFolder = ServicesFolder.Services

local RunService = game:GetService("RunService")

local MyServices = {}

MyServices["Services"] = {}

function MyServices:FetchAllServices()
	local function getRunningIn()
		if RunService:IsClient() then
			return "Client"
		elseif RunService:IsServer() then
			return "Server"
		end
	end

	local runningIn = getRunningIn()

	for i, service in pairs(StorageFolder:GetChildren()) do
		if service:IsA("ModuleScript") and (service:GetAttribute("RunType") == "Global" or service:GetAttribute("RunType") == runningIn) then
			local serviceName = service.Name
			local serviceData = require(service)

			if serviceData["_init"] then
				task.spawn(function()
					local initResult = serviceData:_init()

					if initResult then
						print("[Module Loader]: Successfully initialized ".. serviceName ..".")
					else
						warn("[Module Loader]: Unable to initialize ".. serviceName ..".")
					end
				end)
			end

			self["Services"][serviceName] = serviceData
		end
	end
end

function MyServices:GetService(ServiceName: string)
	local MaxAttempts = 3
	local AttemptInterval = .3

	local function attempt()
		for serviceName, serviceData in pairs(self["Services"]) do
			if serviceName == ServiceName then
				return serviceData
			end
		end
	end

	for i = 1, MaxAttempts, 1 do
		task.wait(AttemptInterval)

		local attemptResult = attempt()

		if attemptResult then
			return attemptResult
		elseif i == MaxAttempts and not attemptResult then
			warn("[Module Loader]: Was unable to load ".. ServiceName .." for a specific service.")
		end
	end
end

return MyServices