local json = require "json"
local utils = require "utils"
local anims = require "anims"

local M = {}

local tweets = {}
local tweet_idx = 0

local unwatch = util.file_watch("tweets.json", function(raw)
    tweets = json.decode(raw)
    tweet_idx = 0
    for idx = #tweets,1,-1 do
        local tweet = tweets[idx]
        local ok, profile = pcall(resource.open_file, tweet.profile_image)
        if not ok then
            print("cannot use this tweet. profile image missing", profile)
            table.remove(tweets, idx)
        end
        tweet.profile = profile 
        tweet.lines = utils.wrap(tweet.text, 27)
    end
end)

function M.unload()
    unwatch()
end

function M.prepare(options)
    local tweet
    tweet, tweet_idx = utils.cycled(tweets, tweet_idx)
    return options.duration or 10, tweet
end

function M.run(duration, tweet, fn)
    local img = resource.load_image(tweet.profile:copy())

    local y = 200
    local a = utils.Animations()

    local S = 0
    local E = duration

    a.add(anims.moving_font(S, E, 310, y+20, "@"..tweet.screen_name, 60)); S=S+0.1; y=y+150
    for idx = 1, #tweet.lines do
        local line = tweet.lines[idx]
        a.add(anims.moving_font(S, E, 200, y, line, 100)); S=S+0.1; y=y+100
    end
    y = y + 20

    local age = Time.unixtime() - tweet.created_at
    if age < 100 then
        age = string.format("%ds", age)
    elseif age < 3600 then
        age = string.format("%dm", age/60)
    else
        age = string.format("%dh", age/3600)
    end
    a.add(anims.moving_font(S, E, 200, y, age .. " ago", 50)); S=S+0.1; y=y+60

    a.add(anims.tweet_profile(S, E, 200, 200, img, 100))

    for now in fn.upto_t(E) do
        a.draw(now)
    end

    img:dispose()
    return true
end

return M
