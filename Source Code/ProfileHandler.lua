-- Services
local Players = game:GetService("Players")
local DSS = game:GetService("DataStoreService")
local RS = game:GetService("RunService")

local Settings = require(script.Settings)
local Functions = require(script.Functions)
local Signal = require(script.Signal)

local log = Functions.log
local defaultData = Settings.defaultData
local Heartbeat = RS.Heartbeat

local ProfileHandler = {}
ProfileHandler.__index = ProfileHandler
ProfileHandler.ClassName = "ProfileHandler"
ProfileHandler.StoreCache = {}

-- Profile Functions
local Profile = {}

function Profile:ClearOldBackups()
	local orderedStore = self.orderedStore
	local backupStore = self.backupStore
	
	local oldBackups = nil
	local clearSuccess,clearError = pcall(function()
		oldBackups = orderedStore:GetSortedAsync(false,50,-math.huge,self.latestVersion-Settings.maxBackups)
	end)

	if oldBackups then
		local backupsPage = oldBackups:GetCurrentPage()

		for index, info in ipairs(backupsPage) do
			local wasSuccess,errorMessage = pcall(function()
				backupStore:RemoveAsync(info.value)
				orderedStore:RemoveAsync(info.value)
			end)
		end
	end
end

function Profile:UpdateBackup(num)
	-- If 'num' is nil, it will get the latest
	
	local backupStore = self.backupStore
	local orderedStore = self.orderedStore
	
	local backupData = nil
	local orderedData = nil
	
	local orderedSuccess,orderedError = pcall(function()
		orderedData = orderedStore:GetSortedAsync(false,Settings.maxBackups)
	end)
	
	if orderedSuccess then
		-- Got ordered data
		local orderedPage = orderedData:GetCurrentPage()
		
		local latestVersion = (orderedPage[1] and orderedPage[1].value) or 0
		self.latestVersion = latestVersion
		
		self:ClearOldBackups()
		
		if not num then
			-- Get latest
			for _,backup in ipairs(orderedPage) do
				
				local gotBackup,backupData = Functions.getDataFromVersion(backup,backupStore)

				if gotBackup then
					self.backup = backupData.data
					return true,backupData.data
				else
					wait()
				end
				
			end
			return false
		else
			
			local backup = orderedPage[num]
			
			local gotBackup,backupData = Functions.getDataFromVersion(backup,backupStore)

			if gotBackup then
				self.backup = backupData.data
				return true,backupData.data
			else
				self.orderedFail()
				return false
			end
			
		end
	else
		self.orderedFail()
	end
end

function Profile:LoadBackup(num)
	if not self.backup then
		self:UpdateBackup()
	end
	self:Set(self.backup)
end

function Profile:Get(defaultValue)
	
	if not self.backup then -- No backup
		log("Updating backup")
		self:UpdateBackup()
	end
	
	local sessionLock = self.sessionLock
	local data = nil
	local isSuccessful = true
	
	if not self.cache then
		-- Get from roblox servers
		log("Queueing")
		self:Queue()
		
		log("Attempting to load from DataStore servers")
		
		local mainSuccess,mainError = pcall(function()
			
			data = self.mainStore:UpdateAsync(self.key,function(oldData)
				
				if oldData then
					log("Got old data")
					
					if oldData.locked then
						log("Old data is locked!")
						
						if os.time()-oldData.time <= Settings.timeUntilSessionsIsDead then
							-- Session is not dead, but still locked
							log("Triggering callback")
							isSuccessful = false
							self.isLocked(Settings.timeUntilSessionsIsDead-(os.time()-oldData.time))
							return
						else
							-- Session is dead, using a backup
							log("Session is dead, using last backup")
							if self.backup then
								log("Successfully found backup")
								return Functions.format(self.backup,sessionLock)
							else
								log("No backup found!")
								isSuccessful = false
								self.deadNoBackup()
								return Functions.format(defaultValue,sessionLock)
							end
						end
						
					else
						log("Updating old data")
						-- It isn't locked!
						oldData.locked = true
						return Functions.format(oldData.data or defaultValue,sessionLock)

					end
				else
					
					log("No data found, using default data")
					return Functions.format(defaultValue,sessionLock)
					
				end
				
			end).data

		end)
		
		if not mainSuccess then
			log(mainError)
			isSuccessful = false
			data = nil
			self.mainError(mainError)
		else
			self.cache = data
		end
	else
		log("Loading from cache")
		data = self.cache
	end
	
	return data,isSuccessful
end

function Profile:Save(isFinal)
	log("Attempting to save")
	
	local finalSave = self.isPlayerStore and isFinal
	
	if not self.cache then
		log("No data found in cache, dropping request")
		if finalSave then
			wait(0.5)
			self.FinalSaved:Fire()
		end
		return
	else
		log("Using data in cache")
	end
	
	if not self.latestVersion then
		log("No latest version found, attempting to retrieve it")
		local backupSuccess = Profile:UpdateBackup()
		
		if not backupSuccess then
			log("Backup failed, dropping save request")
			return
		end
	end
	
	local nextVersion = self.latestVersion+1
	local formattedData = Functions.format(self.cache or self.backup,false)
	
	log("Queueing")
	self:Queue()
	local wasSuccess,Error = pcall(function()
		-- Update main store
		log("Saving to main store")
		self.mainStore:UpdateAsync(self.key,function(oldData)
			if oldData ~= formattedData then
				return formattedData
			else
				return
			end
		end)
		
		-- Update backup store
		log("Saving to backup store")
		self.backupStore:SetAsync(nextVersion,formattedData)
		
		-- Update ordered store
		log("Saving to ordered store")
		self.orderedStore:SetAsync(nextVersion,nextVersion)
	end)
	
	if not wasSuccess then
		self.saveFail(Error)
	end
	
	self.Updated:Fire()
	
	if finalSave then
		wait(0.5)
		self.FinalSaved:Fire()
		self:Release()
	end
end

function Profile:Set(newValue)
	if not self.cache then
		log("Dropping request, no cache")
	end
	if not self.latestVersion then
		self:UpdateBackup()
	end
	self.cache = newValue
end

function Profile:Increment(value)
	if not self.binded then
		self:Set(self:Get(0)+value)
	elseif self.binded:IsA("IntValue") or self.binded:IsA("NumberValue") then
		self.binded.Value = self.binded.Value+value
	end
end

function Profile:ClearCache()
	self.cache = nil
end

function Profile:ClearBackupCache()
	self.backup = nil
	self.latestVersion = nil
end

function Profile:Queue()
	local lastUpdated = self.lastUpdated
	self.lastUpdated = os.clock()+Settings.updateCooldown
	while os.clock()-lastUpdated <= Settings.updateCooldown do Heartbeat:wait() end
	
end

function Profile:BindToLock(funct)
	self.isLocked = funct
end

function Profile:BindToError(case,funct)
	self[case] = funct
end

function Profile:Bind(value)
	self.binded = value
	self.bind = value:GetPropertyChangedSignal("Value"):Connect(function()
		self:Set(value.Value)
	end)
end

function Profile:Release()
	if self.bind then
		self.bind:Disconnect()
	end
	ProfileHandler.StoreCache[self.name].keyCache[self.key] = nil
	self = nil
end

-- Store Functions
local DataStore = {}

function DataStore.__call(self,key,sessionLock)

	local name = self.name
	local backupKey = name.."/"..key

	local DFF = Settings.defaultFailFunction -- Default fail functions

	if sessionLock == nil then
		sessionLock = true
	end

	self.keyCache[key] = self.keyCache[key] or setmetatable({
		name = name;
		key = key;
		sessionLock = sessionLock;

		lastUpdated = 0;

		cache = nil;
		backup = nil;
		latestVersion = nil;

		mainStore = self.store;
		backupStore = DSS:GetDataStore(backupKey);
		orderedStore = DSS:GetOrderedDataStore(backupKey);

		-- Error callbacks
		saveFail = DFF;
		deadNoBackup = DFF;
		isLocked = DFF;
		mainError = DFF;

		-- Events
		Updated = Signal.new()
	},{
		__index = function(_,call)
			return Profile[call]
		end
	})

	return self.keyCache[key]
end

setmetatable(DataStore,DataStore)

-- Store Functions
local PlayerStore = {}

function PlayerStore.__call(self,plr)
	
	local key = plr.UserId

	local name = self.name
	local backupKey = name.."/"..key

	local DFF = Settings.defaultFailFunction -- Default fail functions

	self.keyCache[key] = self.keyCache[key] or setmetatable({
		name = name;
		key = key;
		sessionLock = true;

		lastUpdated = 0;

		cache = nil;
		backup = nil;
		latestVersion = nil;

		mainStore = self.store;
		backupStore = DSS:GetDataStore(backupKey);
		orderedStore = DSS:GetOrderedDataStore(backupKey);
		
		isPlayerStore = true;

		-- Error callbacks
		saveFail = DFF;
		deadNoBackup = DFF;
		isLocked = function(timeTilDead)
			plr:Kick("Data is still saving. If your data data still hasn't saved in "..timeTilDead.." seconds, a backup will be used.")
		end;
		mainError = DFF;

		-- Events
		Updated = Signal.new();
		FinalSaved = Signal.new();
	},{
		__index = function(_,call)
			return Profile[call]
		end
	})

	return self.keyCache[key]
end

setmetatable(PlayerStore,PlayerStore)

-- Handler Functions
function ProfileHandler:GetProfileStore(storeName)
	self.StoreCache[storeName] = self.StoreCache[storeName] or setmetatable({
		name = storeName;
		store = DSS:GetDataStore(storeName);
		keyCache = {};
	},DataStore)

	return self.StoreCache[storeName]
end

function ProfileHandler:GetPlayerStore(storeName) -- Made especially for player data
	
	if not self.StoreCache[storeName] then
		Players.PlayerRemoving:connect(function(plr)
			self.StoreCache[storeName](plr):Save(true)
		end)

		game:BindToClose(function()

			log("Server closing")
			
			if RS:IsStudio() then
				local plrList = Players:GetPlayers()
				
				local finalSaved = {}

				for _,plr in pairs(plrList) do
					self.StoreCache[storeName](plr).FinalSaved:Connect(function()
						log(plr.Name.." has finished saving")
						finalSaved[plr] = true
					end)
				end

				while wait() do
					local allIsLoaded = true
					for _,plr in pairs(plrList) do
						if not finalSaved[plr] then
							allIsLoaded = false
						end
					end
					if allIsLoaded then
						break
					end
				end

				log("Server has closed and all data has been saved")
				return
			else
				wait(60)
			end
		end)
	end
	
	self.StoreCache[storeName] = self.StoreCache[storeName] or setmetatable({
		name = storeName;
		store = DSS:GetDataStore(storeName);
		keyCache = {};
	},PlayerStore)
	
	return self.StoreCache[storeName]
end

return setmetatable(ProfileHandler,ProfileHandler)
