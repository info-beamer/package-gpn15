local utils = require "utils"

local M = {}

local function rotating_entry_exit(S, E, obj)
    local rotate = utils.make_smooth{
        {t = S ,  val = -60},
        {t = S+1 ,val =   0, ease='step'},
        {t = E-1, val =   0},
        {t = E,   val = -90},
    }

    return function(t)
        gl.rotate(rotate(t), 0, 1, 0)
        return obj(t)
    end
end

local function move_in_move_out(S, E, x, y, obj)
    local x = utils.make_smooth{
        {t = S,   val = x+2200},
        {t = S+1, val = x, ease='step'},
        {t = E-1, val = x},
        {t = E,   val = -2000},
    }

    local y = utils.make_smooth{
        {t = S,   val = y*3},
        {t = S+1, val = y, ease='step'},
        {t = E-1, val = y},
        {t = E,   val = 0},
    }

    return function(t)
        gl.translate(x(t), y(t))
        return obj(t)
    end
end

function M.moving_font(S, E, x, y, text, size)
    return move_in_move_out(S, E, x, y,
        rotating_entry_exit(S, E, function(t)
            res.font:write(0, 0, text, size, 0,0,0,1)
        end)
    )
end

function M.moving_font_shake(S, E, x, y, text, size, shake)
    return move_in_move_out(S, E, x, y, 
        rotating_entry_exit(S, E, function(t)
            local dx, dy
            dx = 0
            dy = 0
            if shake then 
                dx = math.sin(t*8*4)*2
                dy = math.sin(t*9*4)*2
            end
            res.font:write(dx, dy, text, size, 0,0,0,1)
        end)
    )
end

function M.moving_font_list(S, E, x, y, texts, size)
    return move_in_move_out(S, E, x, y, 
        rotating_entry_exit(S, E, function(t)
            local alpha = 1
            local text = texts[math.floor((t+0.5) % #texts + 1)]
            if #texts > 1 then
                local rot = (180 * t + 90) % 180 - 90
                alpha = math.sqrt(math.abs(math.cos(t * math.pi)))
                gl.translate(0, size/2)
                gl.rotate(rot, 1, 0, 0)
                gl.translate(0, -size/2)
            end
            res.font:write(0, 0, text, size, 0,0,0,alpha)
        end)
    )
end

function M.tweet_profile(S, E, x, y, img, size)
    local x = utils.make_smooth{
        {t = S+0, val = 2200},
        {t = S+1, val = 500},
        {t = S+2, val = x, ease='step'},
        {t = E-1, val = x},
        {t = E,   val = -2000},
    }

    local y = utils.make_smooth{
        {t = S+0, val = HEIGHT/2},
        {t = S+1, val = 200},
        {t = S+2, val = y, ease='step'},
        {t = E-1, val = y},
        {t = E,   val = 0},
    }

    local scale = utils.make_smooth{
        {t = S ,  val = 0},
        {t = S+1, val = 8},
        {t = S+2, val = 1, ease='step'},
        {t = E-1, val = 1},
        {t = E,   val = 8},
    }

    return function(t)
        local size = scale(t) * size
        gl.translate(x(t), y(t))
        util.draw_correct(img, 0, 0, size, size)
    end
end


return M
