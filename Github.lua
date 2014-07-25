-- GithubAPI :: Github

local Github = {}
--[[
local function isLuaFile(path)
    return path:endsWith('.lua')
end
]]--
local function load(todo, callback)
    if #todo == 0 then return callback() end
    local current = todo[1]
    table.remove(todo, 1)
    local f = function()
        return load(todo, callback)
    end
    GithubAPI.Repositories.Contents.get({ path = current }, function(data)
        if (data.name == "README.md" or data.name == "module.json") then data.content = '--[[\n' .. data.content .. '\n]]--' end
        saveProjectTab("GitClient-Release:" .. data.name:gsub('%..*$', ''), data.content)
        f()
    end)
end

-- @todo : support subdirectories, gitignore and filters
local function loader(data, callback, noSubdirectories)
    local todo = {}
    for k,v in pairs(data) do
        todo[#todo+1] = v.name
    end
    --[[
    for k,v in pairs(data) do
        if v.type == "directory" and not noSubdirectories then
            -- print('load subdirectory ' .. v.name)
            -- @todo
        elseif v.type == "file" and isLuaFile(v.name) then
            todo[#todo+1] = v.name
        else
            print("Not downloaded : " .. v.name)
        end
    end
    ]]--
    load(todo, callback)
end

function Github.get(arg, callback)
    -- @todo check if the repo (or path) exist in codea and stock it for save tabs
    GithubAPI.Repositories.Contents.get(arg, function(data)
        loader(data, callback)
    end)
end

local function update(current, message, f)
    print('update', current.path)
    GithubAPI.Repositories.Contents.update({
        path = current.path,
        message = message,
        content = current.content,
        sha = current.sha
    }, f)
end

local function create(current, message, f)
    print('create', current.path)
    GithubAPI.Repositories.Contents.create({
        path = current.path,
        message = message,
        content = current.content
    }, f)
end

local function commit_aux(todo, message, callback)
    if #todo == 0 then return callback() end
    local current = todo[1]
    table.remove(todo, 1)
    local f = function()
        return commit_aux(todo, message, callback)
    end
    if current.sha then
        return update(current, message, f)
    else
        return create(current, message, f)
    end
end

-- @todo
--
-- get the current commit object
-- retrieve the tree it points to
-- retrieve the content of the blob object that tree has for that particular file path
-- change the content somehow and post a new blob object with that new content, getting a blob SHA back
-- post a new tree object with that file path pointer replaced with your new blob SHA getting a tree SHA back
-- create a new commit object with the current commit SHA as the parent and the new tree SHA, getting a commit SHA back
-- update the reference of your branch to point to the new commit SHA
--
-- for the moment, there is one commit by file included if sha is the same (create empty commits)
--
function Github.commit(projectname, message, callback)
    print("Wait, commit in progress...")
    
    local tabs = keys(listProjectTabs(), readProjectTab)
    -- local gitignore = tkeys.Gitignore and readProjectTab('Gitignore') or {}
    
    tabs.Main = nil
    if tabs.README then
        tabs.README = tabs.README:gsub('^%-%-%[%[\n', ''):gsub('\n%]%]%-%-$', '')
    end
    -- tabs.Gitignore = nil
    
    GithubAPI.Repositories.Contents.get({ path = projectname }, function(data)
        local todo = {}

        -- path, type, sha, name
        local fdata = keys(data, function(v) return v end, function(v) return v.name end)
        for k,v in pairs(tabs) do
            todo[#todo+1] = { content = v }
            local filename
            if (k == 'README') then
                filename = k .. ".md"
            else
                filename = k .. ".lua"
            end
            if fdata[filename] then -- update
                todo[#todo].path = fdata[filename].path
                todo[#todo].sha = fdata[filename].sha
            else
                todo[#todo].path = projectname .. "/" .. k .. ".lua"
            end
        end
        
        commit_aux(todo, message, callback)
    end)
end

return Github