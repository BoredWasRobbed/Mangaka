local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServiceHandler = require(ReplicatedStorage.Shared.MyServices.Handler)

ServiceHandler:FetchAllServices()
