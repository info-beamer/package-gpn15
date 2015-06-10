local json = require "json"
local utils = require "utils"
local anims = require "anims"

local M = {}

local MAX_DISPLAY = 6
local SPEAKER_SIZE = 50
local TITLE_SIZE = 60
local TIME_SIZE = 60


local talks = {}

local unwatch = util.file_watch("talks.json", function(raw)
    print "talk.json updated!"
    talks = json.decode(raw)
end)

function M.unload()
    unwatch()
end

function M.prepare(options)
    local now = Time.unixtime()

    local lineup = {}
    for idx = 1, #talks do
        local talk = talks[idx]

        -- Aktuell laufende (fuer 15 Minuten)
        if now > talk.start_unix and now < talk.end_unix then
            if talk.start_unix + 15 * 60 > now then
                lineup[#lineup+1] = talk
            end
        end

        -- Bald startende
        if talk.start_unix > now and #lineup < 6 then -- and talk.start_unix < now + 86400 then
            lineup[#lineup+1] = talk
        end
    end

    table.sort(lineup, function(t1, t2)
        return t1.start_unix < t2.start_unix or (t1.start_unix == t2.start_unix and t1.place < t2.place)
    end)

    print(#talks, "talks, ", #lineup, "lineups")

    local next_talks = {}
    local places = {}
    local redundant = false
    for idx = 1, #lineup do
        local talk = lineup[idx]
        if #next_talks < MAX_DISPLAY then
            redundant = redundant or places[talk.place];
            next_talks[#next_talks+1] = {
                speakers = #talk.speakers == 0 and {"?"} or talk.speakers;
                place = talk.place;
                lines = utils.wrap(talk.title .. " (" .. talk.lang .. ")", 38);
                start_str = talk.start_str;
                start_unix = talk.start_unix;
                redundant = redundant;
                started = talk.start_unix < now;
            }
            if talk.start_unix > now then
                places[talk.place] = true
            end
        end
    end

    return options.duration or 10, next_talks
end

function M.run(duration, next_talks, fn)
    local y = 100
    local a = utils.Animations()

    local S = 0
    local E = duration

    if #next_talks == 0 then
        a.add(anims.moving_font(S, E, 200, y, "Keine weiteren Vorträge", 60)); y=y+60; S=S+0.5
        a.add(anims.moving_font(S, E, 200, y, "Bitte helft beim Abbau. Danke", 60))
    end

    for idx = 1, #next_talks do
        local talk = next_talks[idx]

        local now = Time.unixtime()
        local time
        local til = talk.start_unix - now
        if til > 0 and til < 60 * 15 then
            time = string.format("In %d min", math.floor(til/60))
        elseif talk.start_unix > now then
            time = talk.start_str
        else
            time = "Seit " .. talk.start_str
        end

        a.add(anims.moving_font_shake(S, E, 200, y, time, TIME_SIZE, talk.started))

        for idx = 1, #talk.lines do
            local line = talk.lines[idx]
            a.add(anims.moving_font(S, E, 420, y, line, TITLE_SIZE))
            y = y + TITLE_SIZE
        end
        S = S + 0.1

        local text = talk.place .. " mit "
        a.add(anims.moving_font(S, E, 420, y, text, SPEAKER_SIZE)); S=S+0.1
        local w = res.font:width(text, SPEAKER_SIZE)
        a.add(anims.moving_font_list(S, E, 420 + w + 5, y, talk.speakers, SPEAKER_SIZE))

        S = S + 0.1
        y = y + SPEAKER_SIZE + 25
    end

    for now in fn.upto_t(E) do
        a.draw(now)
    end
    return true
end

return M

