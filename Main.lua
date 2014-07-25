-- GithubAPI :: Main

package.path = os.getenv("HOME") .. "/Documents/GithubAPI.codea/?.lua"

local GithubAPI = require "GithubAPI"

function table.print(tbl, indent)
    if not indent then indent = 0 end
    for k, v in pairs(tbl) do
        local formatting = string.rep("  ", indent) .. k .. ": "
        if type(v) == "table" then
            print(formatting)
            table.print(v, indent+1)
        else
            print(formatting .. tostring(v))
        end
    end
end

local function resp(data)
    table.print(data)
end

local function response(data, status, headers)
    table.print(data)
    print(status)
    table.print(headers)    
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

function getBlobs(tree, callback)
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
        elseif k == "module" then
            path = k .. ".json"
        else
            path = k .. ".lua"
        end
        entries[#entries+1] = {
            path = path,
            content = content
        }
    end
    
    getBlobs_aux(entries, {}, function(blobs)
        table.print(formattedTree)
        
        for i,blob in ipairs(blobs) do
            if formattedTree[blob.path] then
                print(blob.path, 'already up to date ?', formattedTree[blob.path].sha, blob.sha)
            else
                print('new :', blob.path)
            end
            if formattedTree[blob.path] and formattedTree[blob.path].sha == blob.sha then -- up to date
                print('removed')
                blobs[i] = nil
            end
        end
        
        callback(blobs)
    end)
end

function setup()
    GithubAPI:init() -- utilities enabled
    GithubAPI.debug = true -- print called urls
    
    GithubAPI.default.owner = "HyroVitalyProtago"
    GithubAPI.default.repo = "GithubAPI"
    
    parameter.action("Github", function()
        openURL('http://www.github.com/HyroVitalyProtago/Codea', true)
    end)
    parameter.action("API", function()
        openURL('https://developer.github.com/v3/', true)
    end)
    parameter.action("Commit", function()
        --[[
        Github.commit("GithubAPI", "GithubAPI tests from Codea", function()
            print("Commit success !")
        end)
        ]]--
    end)
    
    -- try real commit
    --
    
    local commitMessage = "GithubAPI - test real commit"
    -- get the current commit and tree
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
                getBlobs(tree, function(blobs)
                    if (#blobs == 0) then
                        print('Already up to date')
                    else
                        
                        GithubAPI.GitData.Trees.create({
                            base_tree = treeSha,
                            tree = blobs
                        }, function(data)
                            local newTreeSha = data.sha
                
                            GithubAPI.GitData.Commits.create({
                                parents = { commitSha },
                                tree = newTreeSha,
                                message = commitMessage
                            }, function(data)
                                local newCommitSha = data.sha
                    
                                GithubAPI.GitData.References.update({
                                    ref = "heads/master",
                                    sha = newCommitSha,
                                    -- force = true
                                }, function(data)
                                    print('Commit success !!')
                                end)
                            end)
                        end)
                    end
                end)
            end)
        end)
    end)
end

