--[[
# GithubAPI -- Port of GithubAPI v3 in Lua for Codea
## Work in progress

A module called Github provide you some more complicated actions without direct calls to api.

Examples:
- Create a Github repository from your current project in Codea,
- Download an entire project from Github directly into Codea project.
- ...

### Functions

Useful functions for display response of api

	function table.print(tbl, indent)
		if not indent then indent = 0 end
		for k, v in pairs(tbl) do
		local formatting = string.rep("  ", indent) .. k .. ": "
			if type(v) == "table" then
				print(formatting)
				table.print(v, indent + 1)
			else
				print(formatting .. tostring(v))
			end
		end
	end

	function response(data)
		table.print(data)
	end

### Examples

Some little examples (/!\ Could be change before release !)

	GithubAPI.Repositories.Contents.get({
		owner = "HyroVitalyProtago",
		repo = "Codea",
		path = "GithubAPI"
	}, response)
  
	GithubAPI.default.owner = "HyroVitalyProtago"
	GithubAPI.default.repo = "Codea"
	
	GithubAPI.Repositories.Contents.update({
		path = "GithubAPI/GithubAPI.lua",
		message = "New commit from Codea !",
		content = readProjectTab('GithubAPI'),
		sha = ...
	}, response)
	
	Github.commit({
		path = "GithubAPI", 
		message = "Commit of all current codea project in GithubAPI"
	}, function()
		print('Commit success !')
	end)

***

]]--