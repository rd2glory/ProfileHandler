# ProfileHandler

ProfileHandler is a data module developed by iamtryingtofindname, which makes use of session locking for saving player data and using ordered data stores for backups. It was made intuitive enough for a beginner to understand, while still powerful for experienced scripters.

## Download
You can download the module off of roblox [here](https://www.roblox.com/library/6478371036/ProfileHandler).

## DevForum Post
You can view the original developer forum post [here]() in case you may have a question.

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
OR if you are using :GetPlayerStore(), then use
```
ProfileStore(player)
```
This is used to get an object that is exclusive to a certain key or player. This returns a Profile object.

