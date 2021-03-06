# ProfileHandler

ProfileHandler is a data module developed by iamtryingtofindname, which makes use of session locking for saving player data and using ordered data stores for backups. It was made intuitive enough for a beginner to understand, while still powerful for experienced scripters.

## Download
You can download the module off of roblox [here](https://www.roblox.com/library/6478371036/ProfileHandler).

## DevForum Post
You can view the original developer forum post [here](https://devforum.roblox.com/t/--/1087132) in case you may have a question.

## Documentation

### ProfileHandler:GetProfileStore
```
ProfileHandler:GetProfileStore(profileName)
```
Gets a profile store, similar to how DataStoreService:GetDataStore() would act. It is reccomended that you call this once at the beggining of a script. This returns a ProfileStore object.

### ProfileHandler:GetPlayerStore
```
ProfileHandler:GetPlayerStore(profileName)
```
Has the same functionality as :GetProfileStore(), except it includes automatic saving for all keys when a player leaves the game. Only use this function to get data that is EXCLUSIVELY MEANT FOR PLAYERS. This is reccomended over :GetProfileStore() when dealing with player data.

### ProfileStore()
```
ProfileStore(key)
```
**OR if you are using :GetPlayerStore(), then use**
```
ProfileStore(player)
```
This is used to get an object that is exclusive to a certain key or player. This returns a Profile object.

### Profile:Get
```
Profile:Get(defaultValue)
```
Retrieves data from the key of the given profile. It will access Roblox DataStores when there is no cached data. If there is cached data, it will return this. If all else fails, it will try and return a backup. If there is no previous data on the DataStores, the defaultValue will be used instead. These requests can be queued.

### Profile:Set
```
Profile:Set(newValue)
```
Sets cached data to newValue. This will error if data is not first retrieved using Profile:Get().

### Profile:Increment
```
Profile:Increment(num)
```
Similar behavior to Profile:Set(), except this is exclusively to be used when data is a number. A positive number will raise the value, a negative number will lower the value.

### Profile:Save
```
Profile:Save()
```
Forces a save to Roblox's DataStores with any cached data. If there is no cached data, the request will be dropped. These requests can be queued.

### Profile:UpdateBackup
```
Profile:UpdateBackup()
```
Updates backups for given profile. This will be done by default when running Profile:Get() with no cached data, so this is most likely not needed to be used often. It is reccomended to call this a maximum of 2 times a minute, to prevent throttling.

### Profile:LoadBackup
```
Profile:LoadBackup()
```
Replaces cached data with cached backup. If there is no cached backup, it will call Profile:UpdateBackup().

### Profile:ClearOldBackups
```
Profile:ClearOldBackups()
```
Clears and backups that are older than what is stated in settings. This clears it from Roblox's DataStores. This is most likely not ever needed, as it is done on it's own when calling Profile:UpdateBackup().

### Profile:ClearCache
```
Profile:ClearCache()
```
Replaces main cache with nil. This does not affect backup cache.

### Profile:ClearBackupCache
```
Profile:ClearBackupCache()
```
Replaces backup cache with nil. This does not affect main cache.

### Profile:BindToLock
```
Profile:BindToLock(handler)
```
Binds given handler to profile whenever the profile's data is session locked. There is a default handler which kicks the profile's player, so this is not needed unless you wish to add to it. This function will only take affect if it is a PlayerStore.

### Profile:BindToError
```
Profile:BindToLock(case,handler)
```
Binds given handler to profile whenever the an error is encountered. By default, it prints the error in the console. 

### Profile:Bind
```
Profile:Bind(valueObject)
```
Binds the given valueObject to the Profile. The valueObject can be an IntValue, NumberValue, StringValue, etc. Any changes made to the value will affect the profiles cached data.

### Profile:Release
```
Profile:Release()
```
Releases the given Profile. This deletes all cache and deletes the profile all-togther. A good example of when to use this is when a player is leaving, however, PlayerStores have this covered already.
