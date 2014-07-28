-- GithubAPI :: GithubAPI

-- Pagination : page, per_page
-- Link header : next, last, first, prev

local GithubAPI = {
    debug = false,
    location = "https://api.github.com/",
    accept = "application/vnd.github.v3+json",
    token = readGlobalData("Github_access_token"),
    default = {},
    OAuth = {
        authorizations = {}
    },
    Gists = {
        list = {},
        Comments = {}
    },
    PullRequests = {},
    Repositories = {
        list = {},
        Contents = {},
        Merging = {}
    },
    GitData = {
        Blobs = {},
        Commits = {},
        References = {},
        Tags = {},
        Trees = {}
    },
    Codea = {}
}

local Utilities = require "Utilities"
local Codea = require "Codea"

local request, required, uri, data, post, put, patch, delete, encode, decode =
        Utilities.request, Utilities.required, Utilities.uri, Utilities.data, Utilities.post, Utilities.put,
        Utilities.patch, Utilities.delete, Utilities.encode, Utilities.decode

function GithubAPI:init()
    Utilities.init(self)
    Codea.init(self)
    self.Codea = Codea
end

-- Redirect users to request GitHub access --
function GithubAPI.OAuth.getToken(client_id, scope, callback)
    request("https://github.com/login/oauth/authorize?client_id="..client_id.."&scope="..scope, function(data, status, headers)
        GithubAPI.OAuth._getToken(client_id, client_secret, data, callback)
    end, nil, true)
end

-- GitHub redirects back to your site --
function GithubAPI.OAuth._getToken(client_id, client_secret, code, callback)
    request("https://github.com/login/oauth/access_token", callback, {
        method = "POST",
        data = {
            client_id = client_id,
            client_secret = client_secret,
            code = code
        }
    }, true)
end

-- List your authorizations --
function GithubAPI.OAuth.authorizations.list(callback)
    request("authorizations", callback)
end

-- Get a single authorization --
function GithubAPI.OAuth.authorizations.get(id, callback)
    request("authorizations/"..id, callback)
end

-- Create a new authorization --
function GithubAPI.OAuth.authorizations.create(callback, scopes, note, note_url, client_id, client_secret)
    request("authorizations/", callback, {
        method = "POST",
        data = {
            scopes = scopes,
            note = note,
            note_url = note_url,
            client_id = client_id,
            client_secret = client_secret
        }
    })
end

--- GISTS ---

-- List gists
function GithubAPI.Gists.list.user(user, callback)
    request("users/"..user.."/gists", callback)
end
function GithubAPI.Gists.list.all(callback) -- return all public gists if called anonymously
    request("gists", callback)
end
function GithubAPI.Gists.list.allPublic(callback)
    request("gists/public", callback)
end
function GithubAPI.Gists.list.starred(callback)
    request("gists/starred", callback)
end

-- Get a single gist
function GithubAPI.Gists.get(id, callback)
    request("gists/"..id, callback)
end

-- Create a gist
function GithubAPI.Gists.create(arg, callback)
    arg = required(arg, "public", "files")
    request("gists/", callback, post({
        data = data(arg, "public", "files", "description")
    }))
end

-- Edit a gist
function GithubAPI.Gists.edit(id, files, callback, description)
    arg = required(arg, "id", "files")
    request("gists/"..id, callback, patch({
        data = data(arg, "id", "files", "description")
    }))
end

-- Star a gist
function GithubAPI.Gists.star(id, callback)
    request("gists/"..id.."/star", callback, put())
end

-- Unstar a gist
function GithubAPI.Gists.unstar(id, callback)
    request("gists/"..id.."/star", callback, delete())
end

-- Check if a gist is starred
function GithubAPI.Gists.checkStar(id, callback)
    request("gists/"..id.."/star", callback)
end

-- Fork a gist
function GithubAPI.Gists.fork(id, callback)
    request("gists/"..id.."/forks", callback, post())
end

-- Delete a gist
function GithubAPI.Gists.delete(id, callback)
    request("gists/"..id, callback, delete())
end

--- GISTS COMMENTS ---

-- List comments on a gist
function GithubAPI.Gists.Comments.list(gist_id, callback)
    request("gists/"..gist_id.."/comments", callback)
end

-- Get a single comment
function GithubAPI.Gists.Comments.get(gist_id, id, callback)
    request("gists/"..gist_id.."/comments/"..id, callback)
end

-- Create a comment
function GithubAPI.Gists.Comments.create(gist_id, body, callback)
    request("gists/"..gist_id.."/comments", callback, post({
        data = {
            body = body
        }
    }))
end

-- Edit a comment
function GithubAPI.Gists.Comments.edit(gist_id, id, body, callback)
    request("gists/"..gist_id.."/comments/"..id, callback, patch({
        data = {
            body = body
        }
    }))
end

-- Delete a comment
function GithubAPI.Gists.Comments.delete(gist_id, id, callback)
    request("gists/"..gist_id.."/comments/"..id, callback, delete())
end

--- GitData --- @test

-- Blobs --

-- Get a Blob
function GithubAPI.GitData.Blobs.get(arg, callback)
    arg = required(arg, "owner", "repo", "sha")
    request(uri("repos/:owner/:repo/git/blobs/:sha", arg), function(data, status, headers)
        if data.encoding == "base64" then
            data = decode(data, "content")
            data.encoding = "utf-8"
        end
        callback(data, status, headers)
    end)
end

-- Create a Blob
function GithubAPI.GitData.Blobs.create(arg, callback)
    arg = required(arg, "owner", "repo", "content", "encoding") -- encoding : utf-8 or base64
    if arg.encoding == "base64" then arg = encode(arg, "content") end
    request(uri("repos/:owner/:repo/git/blobs", arg), callback, post({
        data = data(arg, "content", "encoding")
    }))
end

-- Commits --

-- Get a Commit
function GithubAPI.GitData.Commits.get(arg, callback)
    arg = required(arg, "owner", "repo", "sha")
    request(uri("repos/:owner/:repo/git/commits/:sha", arg), callback)
end

-- Create a Commit
function GithubAPI.GitData.Commits.create(arg, callback)
    arg = required(arg, "owner", "repo", "message", "tree")
    request(uri("repos/:owner/:repo/git/commits", arg), callback, post({
        data = data(arg, "message", "tree", "parents")
    }))
end

-- References --

-- Get a Reference
function GithubAPI.GitData.References.get(arg, callback)
    arg = required(arg, "owner", "repo", "ref")
    request(uri("repos/:owner/:repo/git/refs/:ref", arg), callback)
end

-- Get all References
function GithubAPI.GitData.References.all(arg, callback)
    arg = required(arg, "owner", "repo")
    request(uri("repos/:owner/:repo/git/refs", arg), callback)
end

-- Create a Reference
function GithubAPI.GitData.References.create(arg, callback)
    arg = required(arg, "owner", "repo", "ref", "sha")
    request(uri("repos/:owner/:repo/git/refs", arg), callback, post({
        data = data(arg, "ref", "sha")
    }))
end

-- Update a Reference
function GithubAPI.GitData.References.update(arg, callback)
    arg = required(arg, "owner", "repo", "ref", "sha")
    request(uri("repos/:owner/:repo/git/refs/:ref", arg), callback, patch({
        data = data(arg, "sha", "force")
    }))
end

-- Delete a Reference
function GithubAPI.GitData.References.delete(arg, callback)
    arg = required(arg, "owner", "repo", "ref")
    request(uri("repos/:owner/:repo/git/refs/:ref", arg), callback, delete())
end

-- Tags --

-- Get a Tag
function GithubAPI.GitData.Tags.get(arg, callback)
    arg = required(arg, "owner", "repo", "sha")
    request(uri("repos/:owner/:repo/git/tags/:sha", arg), callback)
end

-- Create a Tag Object
function GithubAPI.GitData.Tags.create(arg, callback)
    arg = required(arg, "owner", "repo", "tag", "message", "object", "type")
    request(uri("repos/:owner/:repo/git/tags", arg), callback, post({
        data = data(arg, "tag", "message", "object", "type")
    }))
end

-- Trees --

-- Get a Tree
function GithubAPI.GitData.Trees.get(arg, callback)
    arg = required(arg, "owner", "repo", "sha")
    request(uri("repos/:owner/:repo/git/trees/:sha", arg), callback)
end

-- Get a Tree Recursively
function GithubAPI.GitData.Trees.getRecursively(arg, callback)
    arg = required(arg, "owner", "repo", "sha")
    arg.recursive = 1
    request(uri("repos/:owner/:repo/git/trees/:sha", arg, "recursive"), callback)
end

-- Create a Tree
function GithubAPI.GitData.Trees.create(arg, callback)
    arg = required(arg, "owner", "repo", "tree")
    request(uri("repos/:owner/:repo/git/trees", arg), callback, post({
        data = data(arg, "tree", "base_tree")
    }))
end

--- PullRequests ---

-- Link Relations
-- List pull requests
-- Get a single pull request
-- Create a pull request
function GithubAPI.PullRequests.create(arg, callback) -- @todo : with issue alternative
    arg = required(arg, "owner", "repo", "title", "head", "base")
    request(uri("repos/:owner/:repo/pulls", arg), callback, post({
        data = data(arg, "title", "head", "base", "body")
    }))
end

-- Update a pull request
-- List commits on a pull request
-- List pull requests files
-- Get if a pull request has been merged
-- Merge a pull request (Merge Button)


--- Repositories ---

-- List your repositories
function GithubAPI.Repositories.list.own(arg, callback)
    request(uri("user/repos", {}, {"type", "sort", "direction"}), callback)
end

-- List user repositories
function GithubAPI.Repositories.list.user(username, callback, type, sort, direction)
    request("users/" .. username .. "/repos" .. argstouri({
        type = type,
        sort = sort,
        direction = direction
    }), callback)
end

-- List organization repositories
function GithubAPI.Repositories.list.org(org, callback, type)
    request("orgs/" .. org .. "/repos" .. argstouri({
        type = type
    }), callback)
end

-- List all public repositories
function GithubAPI.Repositories.list.all(callback, since)
    request("repositories" .. argstouri({
        since = since
    }), callback)
end

-- Create
function GithubAPI.Repositories.create(name, callback, args)
    args = args or {}
    request("user/repos", callback, {
        method = "POST",
        data = {
            name = name,
            description = args.description,
            homepage = args.homepage,
            private = args.private,
            has_issues = args.has_issues,
            has_wiki = args.has_wiki,
            has_downloads = args.has_downloads,
            team_id = args.team_id, -- org
            auto_init = args.auto_init,
            gitignore_template = args.gitignore_template,
            license_template = args.license_template
        }
    })
end

-- Get
function GithubAPI.Repositories.get(arg, callback)
    arg = required(arg, "owner", "repo")
    request(uri("repos/:owner/:repo", arg), callback)
end

-- Edit
-- List contributors
-- List languages
-- List Teams
-- List Tags
-- List Branches

-- Get Branch
function GithubAPI.Repositories.getBranch(arg, callback)
    arg = required(arg, "owner", "repo", "branch")
    request(uri("repos/:owner/:repo/branches/:branch", arg), callback)
end

-- Delete a Repository

-- Contents --

-- Get the README
function GithubAPI.Repositories.Contents.readme(arg, callback)
    arg = required(arg, "owner", "repo")
    request(uri("repos/:owner/:repo/readme", arg, "ref"), callback)
end

-- Get contents
function GithubAPI.Repositories.Contents.get(arg, callback)
    arg = required(arg, "owner", "repo", "path")
    request(uri("repos/:owner/:repo/contents/:path", arg, "ref"), function(data, status, headers)
        callback(decode(data, "content"), status, headers)
    end)
end

-- Create a file
function GithubAPI.Repositories.Contents.create(arg, callback)
    arg = required(arg, "owner", "repo", "path", "message", "content")
    request(uri("repos/:owner/:repo/contents/:path", arg, "branch"), callback, put({
        data = encode(data(arg, "message", "content"), "content")
    }))
end

-- Update a file
function GithubAPI.Repositories.Contents.update(arg, callback)
    arg = required(arg, "owner", "repo", "path", "sha", "message", "content")
    request(uri("repos/:owner/:repo/contents/:path", arg, "branch"), callback, put({
        data = encode(data(arg, "message", "content", "sha"), "content")
    }))
end

-- Delete a file
-- Get archive link
-- Custom media types

-- Merging --

-- Perform a merge
function GithubAPI.Repositories.Merging.merge(arg, callback)
    arg = required(arg, "owner", "repo", "base", "head")
    request(uri("repos/:owner/:repo/merges", arg), callback, post({
        data = data(arg, "base", "head", "commit_message")
    }))
end

return GithubAPI