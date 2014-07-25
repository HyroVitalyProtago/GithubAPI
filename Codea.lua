-- GithubAPI :: Github

local GithubAPI = nil
local Codea = {}

function Codea.init(gitapi)
    GithubAPI = gitapi
end

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

function Codea.get(arg, callback)
    -- @todo check if the repo (or path) exist in codea and stock it for save tabs
    GithubAPI.Repositories.Contents.get(arg, function(data)
        loader(data, callback)
    end)
end

local function getBlobs_aux(todo, blobs, callback)
    if #todo == 0 then return callback(blobs) end
    local current = todo[1]
    table.remove(todo, 1)
    local f = function(data)
        blobs[#blobs+1] = {
            path = current.path,
            sha = data.sha,
            mode = "100644",
            type = "blob"
        }
        return getBlobs_aux(todo, blobs, callback)
    end
    GithubAPI.GitData.Blobs.create({
        content = current.content,
        encoding = "utf-8"
    }, f)
end

local function getBlobs(conf, tree, callback)
    local formattedTree = {}
    for _,v in ipairs(tree) do
        formattedTree[v.path] = v
    end
    
    local entries = {}
    for _,k in ipairs(listProjectTabs()) do
        local path
        local content = readProjectTab(k)
        if k == "README" then
            path = k .. ".md"
            content = content:gsub('^%-%-%[%[\n', ''):gsub('\n%]%]%-%-$', '')
        elseif k == "module" then
            path = k .. ".json"
            content = content:gsub('^%-%-%[%[\n', ''):gsub('\n%]%]%-%-$', '')
        else
            path = k .. ".lua"
        end
        
        if k ~= "Main" then -- remove Main
            entries[#entries+1] = {
                path = path,
                content = content
            }
        end
    end
    
    getBlobs_aux(entries, {}, function(blobs)
        for i,blob in ipairs(blobs) do
            if not formattedTree[blob.path] then
                print('new :', blob.path)
            elseif formattedTree[blob.path].sha == blob.sha then
                print('up to date',blob.path)
            else
                print('updated',blob.path)
            end
        end
        callback(blobs)
    end)
end

function Codea.commit(conf, callback)
    print("Wait, commit in progress...")
    
    -- @todo
    -- first commit
    -- branch system (codea)
    -- push to master
    
    -- conf
    -- + mode : github, gist (++ CodeaCommunity)
    -- project ; default: current codea project
    -- owner ; default : GithubAPI.default.owner (if not owner and not GithubAPI.default.owner, throw an error)
    -- repo ; default : GithubAPI.default.owner (if not repo and not GithubAPI.default.repo, throw an error)
    -- message ; required
    -- ref ; default : "heads/master"
    -- + path
    -- force ; default : false (reference update force)
    -- noRemove ; default : false (if true, all files in repository and not in Codea are not removed)
    -- filters (array of functionS - call on all files (path, content) return modified path, content)
    
    assert(conf.owner or GithubAPI.default.owner)
    GithubAPI.default.owner = conf.owner or GithubAPI.default.owner
    
    assert(conf.repo or GithubAPI.default.repo)
    GithubAPI.default.repo = conf.repo or GithubAPI.default.repo
    
    GithubAPI.GitData.References.get({
        ref = "heads/master"
    }, function(data)
        local commitSha = data.object.sha
        
        GithubAPI.GitData.Commits.get({
            sha = commitSha
        }, function(data)
            local treeSha = data.tree.sha
            
            GithubAPI.GitData.Trees.get({
                sha = treeSha
            }, function(data)
                local tree = data.tree

                -- return all new or modified files in objects { path, sha, mode = "100644", type = "blob" }
                getBlobs(conf, tree, function(blobs)
                    GithubAPI.GitData.Trees.create({
                        -- base_tree = treeSha, -- comment for overwrite previous tree
                        tree = blobs
                    }, function(data)
                        local newTreeSha = data.sha
                        
                        if newTreeSha == treeSha then
                            print('Repository is already up to date !')
                            callback(0)
                        else
                            GithubAPI.GitData.Commits.create({
                                parents = { commitSha },
                                tree = newTreeSha,
                                message = conf.message
                            }, function(data)
                                local newCommitSha = data.sha
                                GithubAPI.GitData.References.update({
                                    ref = "heads/master",
                                    sha = newCommitSha,
                                    -- force = true
                                }, function(data)
                                    print('Commit success !!')
                                    callback(1)
                                end)
                            end)
                        end
                    end)
                end)
            end)
        end)
    end)
end

return Codea