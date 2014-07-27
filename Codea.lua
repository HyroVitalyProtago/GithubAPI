-- GithubAPI :: Github

local GithubAPI = nil
local Codea = {}

local json = require "Dkjson"

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
        if (data.name == "README.md" or data.name == "package.json") then data.content = '--[[\n' .. data.content .. '\n]]--' end
        error('@todo')
        -- saveProjectTab("GitClient-Release:" .. data.name:gsub('%..*$', ''), data.content)
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
        elseif k == "package" then
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

local function readPackageConf()
    return json.decode((readProjectTab("package")):gsub('^%-%-%[%[\n', ''):gsub('\n%]%]%-%-$', ''))
end

local function formatJson(js)
    local function aux(js, acc, indent)
        if js:len() == 0 then return acc end
        acc = acc .. (string.rep("\t", indent))
        local i = js:find('{')
        local j = js:find('}')
        local k = js:find(',')
        local max = js:len()+1
        if math.min(i or max, j or max, k or max) == k then
            return aux(js:sub(k+1), acc .. js:sub(1,k) .. "\n", indent)
        elseif math.min(i or max, j or max, k or max) == i then
            return aux(js:sub(i+1), acc .. js:sub(1,i) .. "\n", indent + 1)
        else
            return aux(js:sub(j+2), acc .. js:sub(1,j-1) .. "\n" .. (string.rep("\t", indent-1)) .. "}," .. "\n", indent - 1)
        end
    end
    return ((aux(js, "", 0)):gsub(",%s*$", ""))
end

local function savePackageConf(packageConf)
    saveProjectTab("package", "--[[\n" .. formatJson(json.encode(packageConf)) .. "\n]]--")
end

local function patch(version)
    local major, minor, patch = string.match(version, '(%d).(%d).(%d)')
    return string.format("%d.%d.%d", major, minor, patch + 1)
end

local function minor(version)
    local major, minor, patch = string.match(version, '(%d).(%d).(%d)')
    return string.format("%d.%d.%d", major, minor + 1, 0)
end

local function major(version)
    local major, minor, patch = string.match(version, '(%d).(%d).(%d)')
    return string.format("%d.%d.%d", major + 1, 0, 0)
end

function Codea.commit(conf, callback)
    print("Wait, commit in progress...")
    
    local packageConf = readPackageConf()
    
    -- type : PATCH / MINOR / MAJOR
    if (conf.type == "PATCH") then
        packageConf.version = patch(packageConf.version)
    elseif (conf.type == "MINOR") then
        packageConf.version = minor(packageConf.version)
    elseif (conf.type == "MAJOR") then
        packageConf.version = major(packageConf.version)
    else
        error("Codea.commit : type need to be PATCH or MINOR or MAJOR string.")
    end
    
    -- @todo
    -- first commit
    -- branch system (codea)
    -- push to master
    -- version tags
    
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
    
    savePackageConf(packageConf)
    
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
                            local version = "v" .. packageConf.version -- commit prepend version
                            
                            GithubAPI.GitData.Commits.create({
                                parents = { commitSha },
                                tree = newTreeSha,
                                message = version .. " : " .. conf.message
                            }, function(data)
                                local newCommitSha = data.sha
                                GithubAPI.GitData.References.update({
                                    ref = "heads/master",
                                    sha = newCommitSha,
                                    -- force = true
                                }, function(data)
                                    callback(1)
                                    
                                    -- Release
                                    -- local version = "v" .. packageConf.version
                                    --[[
                                    GithubAPI.GitData.Tags.create({
                                        tag = version,
                                        object = newCommitSha,
                                        message = conf.type,
                                        type = "commit"
                                    }, function(data)
                                        GithubAPI.GitData.References.create({
                                            ref = "refs/tags/" .. version,
                                            sha = newCommitSha -- data.sha
                                        }, function(data)
                                            print('Commit success !!')
                                            callback(1)
                                        end)
                                    end)
                                    ]]--
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