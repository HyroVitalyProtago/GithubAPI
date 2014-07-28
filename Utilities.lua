-- GithubAPI :: Utilities

local GithubAPI = nil
local Utilities = {}

-- Some utilities required GithubAPI
-- That's why init GithubAPI is needed

local Base64 = require "Base64"
local json = require "Dkjson"

function Utilities.init(gitapi)
    GithubAPI = gitapi
end

function Utilities.request(url, callback, opts, fullUrl)
    opts = opts or {}
    if not opts.headers then opts.headers = {} end
    
    -- set default headers
    opts.headers.Accept = opts.headers.Accept or GithubAPI.accept or nil
    opts.headers.Authorization = opts.headers.Authorization or (GithubAPI.token and "token " .. GithubAPI.token or nil)
    
    -- json encode data
    opts.data = opts.data and json.encode(opts.data) or nil

    -- set path absolute
    url = fullUrl and url or GithubAPI.location .. url

    -- debug mode
    if GithubAPI.debug then print(url) end
    if GithubAPI.debug then print(opts.data) end
    
    -- success and fail callbacks
    local success = type(callback) == "table" and callback.success or callback
    local fail = type(callback) == "table" and callback.fail or alert
    
    http.request(url, function(data, status, headers)
        data = json.decode(data)
        success(data, status, headers)
    end, fail, opts)
end

function Utilities.post(tbl)
    tbl = tbl or {}
    tbl.method = "POST"
    return tbl
end

function Utilities.put(tbl)
    tbl = tbl or {}
    tbl.method = "PUT"
    return tbl
end

function Utilities.delete(tbl)
    tbl = tbl or {}
    tbl.method = "DELETE"
    return tbl
end

function Utilities.patch(tbl)
    tbl = tbl or {}
    tbl.method = "PATCH"
    return tbl
end

-- GITHUB TIMESTAMP (YYYY-MM-DDTHH:MM:SSZ) to os.time
function Utilities.gtimestamp(githubTime)
    githubTime = githubTime:sub(1, #githubTime-1) -- remove Z
    githubTime = Utilities.explode("T", githubTime)
    githubTime[1] = Utilities.explode("-", githubTime[1])
    githubTime[2] = Utilities.explode(":", githubTime[2])
    return os.time({
        year = tonumber(githubTime[1][1]),
        month = tonumber(githubTime[1][2]),
        day = tonumber(githubTime[1][3]),
        hour = tonumber(githubTime[2][1]),
        min = tonumber(githubTime[2][2]),
        sec = tonumber(githubTime[2][3])
    })
end

function Utilities.explode(div,str) -- credit: http://richard.warburton.it
  if (div=='') then return false end
  local pos,arr = 0,{}
  for st,sp in function() return string.find(str,div,pos,true) end do
    table.insert(arr,string.sub(str,pos,st-1))
    pos = sp + 1
  end
  table.insert(arr,string.sub(str,pos))
  return arr
end

function Utilities.argstouri(args)
    local ret = ""
    for k,v in pairs(args) do
        if string.len(ret) == 0 then
            ret = "?"
        else
            ret = ret .. "&"
        end
        ret = ret .. k .. "=" .. v
    end
    return ret
end

function Utilities.encode(tbl, field)
    tbl[field] = tbl[field] and Base64.encode(tbl[field]) or nil
    return tbl
end

function Utilities.decode(tbl, field)
    tbl[field] = tbl[field] and Base64.decode(tbl[field]) or nil
    return tbl
end

function Utilities.data(args, ...)
    local tbl = {}
    for _,v in ipairs(arg) do
        tbl[v] = args[v]
    end
    return tbl
end

function Utilities.optstouri(args, ...)
    local tbl = {}
    for _,field in ipairs(arg) do
        tbl[field] = args[field] or GithubAPI.default[field] or nil
    end
    return Utilities.argstouri(tbl)
end

function Utilities.uri(url, args, opts) -- replace all :field by arg[field]
    local lurl = ""
    local expl = Utilities.explode("/", url)
    for i,v in ipairs(expl) do
        if (v:sub(1,1) == ":") then
            lurl = lurl .. args[v:sub(2)]
        else
            lurl = lurl .. v
        end
        if i ~= #expl then
            lurl = lurl .. "/"
        end
    end
    return lurl .. Utilities.optstouri(args, opts)
end

function Utilities.defaults(tbl) -- all defaults fields are set (if nil)
    tbl.owner = tbl.owner or GithubAPI.default.owner
    tbl.repo = tbl.repo or GithubAPI.default.repo
    tbl.path = tbl.path or GithubAPI.default.path
    return tbl
end

function Utilities.required(tbl, ...) -- assert if a required field is missing
    tbl = Utilities.defaults(tbl or {})
    for _,field in ipairs(arg) do
        assert(tbl[field], "required field missing : " .. field)
    end
    return tbl
end

function Utilities.keys(tbl, f, g)
    local tmp = {}
    for _,v in ipairs(tbl) do
        tmp[g and g(v) or v] = f and f(v) or true
    end
    return tmp
end

return Utilities