local utils = require "utils"

local M = {}

local images = {}
local imglist = {}
local image_idx = 0

local function update_list()
    imglist = {}
    for filename, file in pairs(images) do
        imglist[#imglist+1] = file
    end
    pp(imglist)
end

local function updated_content(filename)
    if filename:sub(1, 4) == "img_" then
        images[filename] = resource.open_file(filename)
        update_list()
    end
end

local hid_update = node.event("content_update", updated_content)

local hid_remove = node.event("content_remove", function(filename)
    if images[filename] then
        images[filename]:dispose()
        images[filename] = nil
        update_list()
    end
end)

function M.unload()
    node.event_remove(hid_update)
    node.event_remove(hid_remove)
end

-- fill with all available images. we cannot use content_update
-- for that since if might not fire for the initial update since
-- this module is also loaded by a content_update event. All
-- content_update events fired before this module is loaded
-- will be missing. So just use the always correct CONTENTS value.
for k, v in pairs(CONTENTS) do
    updated_content(k)
end

function M.prepare(options)
    local image 
    image, image_idx = utils.cycled(imglist, image_idx)
    return 5, image
end

function M.run(duration, image, fn)
    local x = utils.make_smooth{
        {t = 0,   val = 2000},
        {t = 1,   val = 0, ease='step'},
        {t = 4,   val = 0},
        {t = 5,   val = -1000},
    }
    local y = utils.make_smooth{
        {t = 0,  val = 40},
        {t = 1,  val = 0, ease='step'},
        {t = 4,  val = 0},
        {t = 5,  val = 900},
    }
    local rotate = utils.make_smooth{
        {t = 0, val = 90},
        {t = 1, val = 0, ease='step'},
        {t = 4, val = 0},
        {t = 5, val = -180},
    }
    local scale = utils.make_smooth{
        {t = 0,   val = 0},
        {t = 1,   val = 1, ease='step'},
        {t = 4,   val = 1},
        {t = 5,   val = 0},
    }

    local res = resource.load_image(image:copy(), true)

    for now in fn.wait_next_frame do
        local state, err = res:state()
        if state == "loaded" then
            break
        elseif state == "error" then
            error("preloading failed: " .. err)
        end
    end

    fn.wait_t(0)

    Sidebar.hide(duration-1)
    Fadeout.fade(duration-1)

    for now in fn.upto_t(duration) do
        gl.pushMatrix()
            gl.rotate(rotate(now), 0, 1, 0)
            gl.translate(x(now), y(now))
            local scale = scale(now)
            util.draw_correct(res, 0, 0, WIDTH*scale, HEIGHT*scale)
        gl.popMatrix()
    end

    res:dispose()
    return true
end

return M
