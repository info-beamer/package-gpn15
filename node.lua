local scale = 1.0 -- downscale. 1.0 is fullHD, 2 is half of fullHD

gl.setup(1920 / scale, 1080 / scale)
WIDTH = WIDTH * scale
HEIGHT = HEIGHT * scale

node.set_flag "slow_gc"
node.alias "gpn"
util.init_hosted()

local function ERROR(...)
    print("ERROR: ", ...)
end

-- available resources. global, so they can be used from modules
res = util.resource_loader({
    "gpn15logo.png";
    "font.ttf"
}, {})

local json = require "json"
local utils = require "utils"

-----------------------------------------------------------------------------------------------

Fadeout = (function()
    local current_alpha = 1
    local fade_til = 0

    local function alpha()
        return current_alpha
    end

    local function fade(t)
        fade_til = sys.now() + t
    end

    local function tick()
        local target_alpha = sys.now() > fade_til and 1 or 0

        if current_alpha < target_alpha then
            current_alpha = current_alpha + 0.01
        elseif current_alpha > target_alpha then
            current_alpha = current_alpha - 0.01
        end
    end

    return {
        alpha = alpha;
        tick = tick;
        fade = fade;
    }
end)()

Sidebar = (function()
    local sidebar_width = 480
    local visibility = 0
    local target = 0
    local restore = sys.now() + 1

    local white = resource.create_colored_texture(1,1,1,1)

    local function hide(duration)
        target = 0
        restore = sys.now() + duration
    end

    util.data_mapper{
        ["sidebar/hide"] = function(t)
            hide(tonumber(t))
        end;
    }

    local function draw()
        local max_rotate = 130
        if visibility > 0.01 then
            gl.pushMatrix()
            gl.translate(WIDTH, 0)
            gl.rotate(max_rotate - visibility * max_rotate, 0, 1, 0) 
            gl.translate(-sidebar_width, 0)
            white:draw(0, 0, sidebar_width, HEIGHT, 0.5+(1.0 - Fadeout.alpha()))
            util.draw_correct(res.gpn15logo, 50, 20, sidebar_width-20, 500)
            res.font:write(160, 580, "GPN 15", 80, 0,0,0,1)

            res.font:write(125, HEIGHT-45, "info-beamer.com", 40, 0,0,0, visibility)
            gl.popMatrix()
        end

        local size = 100
        local hour, min = Time.walltime()
        local time = string.format("%d:%02d", hour, min)
        local w = res.font:width(time, size)
        local sidebar_x = WIDTH - sidebar_width + (sidebar_width-w)/2

        local clock_x = utils.easeInOut(visibility, WIDTH-w-10, sidebar_x)
        local clock_y = utils.easeInOut(visibility, HEIGHT-100, 700)
        white:draw(clock_x-10, clock_y, clock_x + w + 10, clock_y + 105, 0.5-visibility/2)
        res.font:write(clock_x, clock_y, time, 100, 0,0,0,1)
    end

    local current_speed = 0
    local function tick()
        if sys.now() > restore then
            target = 1
        end
        local current_speed = 0.05
        visibility = visibility * (1-current_speed) + target * (current_speed)
        draw()
    end

    return {
        tick = tick;
        hide = hide;
        width = sidebar_width;
    }
end)()

Time = (function()
    local base_t = os.time() - sys.now()
    local midnight

    local function unixtime()
        -- return sys.now() + base_t + 86400*3
        return sys.now() + base_t
    end

    local function walltime()
        if not midnight then
            return 0, 0
        else
            local time = (midnight + sys.now()) % 86400
            return math.floor(time/3600), math.floor(time % 3600 / 60)
        end
    end

    util.data_mapper{
        ["clock/unix"] = function(time)
            print("new time: ", time)
            base_t = tonumber(time) - sys.now()
        end;
        ["clock/midnight"] = function(since_midnight)
            print("new midnight: ", since_midnight)
            midnight = tonumber(since_midnight) - sys.now()
        end;
    }

    return {
        unixtime = unixtime;
        walltime = walltime;
    }
end)()

-----------------------------------------------------------------------------------------------

local function ModuleLoader()
    local modules = {}

    local function module_name_from_filename(filename)
        return filename:match "module_(.*)%.lua"
    end

    local function module_unload(module_name)
        if modules[module_name] and modules[module_name].unload then
            modules[module_name].unload()
        end
        modules[module_name] = nil
        node.gc()
    end

    local function module_update(module_name, module)
        module_unload(module_name)
        modules[module_name] = module
        print("loaded modules")
        pp(modules)
    end

    node.event("content_update", function(filename)
        local module_name = module_name_from_filename(filename)
        if module_name then
            module_update(module_name, assert(loadstring(resource.load_file(filename), "=" .. filename))())
        end
    end)
    node.event("content_delete", function(filename)
        local module_name = module_name_from_filename(filename)
        if module_name then
            module_unload(module_name)
        end
    end)

    return modules
end

local function Scheduler(runner, modules)
    local playlist = {}
    local playlist_offset = 0

    util.file_watch("playlist.json", function(raw)
        playlist = json.decode(raw)
        playlist_offset = 0
    end)

    local next_visual = sys.now() + 1
    local next_wake = sys.now()

    local function enqueue(item)
        if not modules[item.module] then
            ERROR("unknown module ", item.module)
            return
        end

        local duration, options = modules[item.module].prepare(item.options or {})
        local visual = {
            starts = next_visual - 1;
            duration = duration;
            module = item.module;
            options = options;
        }

        next_visual = next_visual + duration - 1
        next_wake = next_visual - 3
        print("about to schedule visual ", item.module)
        pp(visual)
        runner.add(visual)
    end

    util.data_mapper{
        ["scheduler/enqueue"] = function(raw)
            enqueue(json.decode(raw))
        end
    }

    local function tick()
        if sys.now() < next_wake then
            return
        end

        local item, can_schedule
        repeat
            item, playlist_offset = utils.cycled(playlist, playlist_offset)
            can_schedule = true
            if item.chance then
                can_schedule = math.random() < item.chance
            end
            if item.hours then
                local hours = {}
                for h in string.gmatch(item.hours, "%S+") do
                    hours[tonumber(h)] = true
                end
                local hour, min = Time.walltime()
                if not hours[hour] then
                    can_schedule = false
                end
            end
        until can_schedule
        enqueue(item)
        node.gc()
    end

    return {
        tick = tick;
    }
end

local function Runner(modules)
    local visuals = {}

    local function add(visual)
        local co = coroutine.create(modules[visual.module].run)

        local success, is_finished = coroutine.resume(co, visual.duration, visual.options, {
            wait_next_frame = function ()
                return coroutine.yield(false)
            end;
            wait_t = function(t)
                while true do
                    local now = coroutine.yield(false)
                    if now >= t then return now end
                end
            end;
            upto_t = function(t) 
                return function()
                    local now = coroutine.yield(false)
                    if now < t then return now end
                end
            end;
        })

        if not success then
            ERROR(debug.traceback(co, string.format("cannot start visual: %s", is_finished)))
        elseif not is_finished then
            table.insert(visuals, 1, {
                co = co;
                starts = visual.starts;
            })
        end
    end

    local function tick()
        local now = sys.now()
        for idx = #visuals,1,-1 do -- iterate backwards so we can remove finished visuals
            local visual = visuals[idx]
            local success, is_finished = coroutine.resume(visual.co, now - visual.starts)
            if not success then
                ERROR(debug.traceback(visual.co, string.format("cannot resume visual: %s", is_finished)))
                table.remove(visuals, idx)
            elseif is_finished then
                table.remove(visuals, idx)
            end
        end
    end

    return {
        tick = tick;
        add = add;
    }
end

-----------------------------------------------------------------------------------------------

local modules = ModuleLoader()
local runner = Runner(modules)
local scheduler = Scheduler(runner, modules)

function node.render()
    Fadeout.tick()

    gl.clear(0,0,0,1)

    if Fadeout.alpha() > 0.04 then
        CONFIG.background.ensure_loaded{
            loop = true;
        }:draw(0, 0, WIDTH, HEIGHT, Fadeout.alpha())
    end

    -- Set perspective projection that acts like ortho
    local fov = math.atan2(HEIGHT, WIDTH*2) * 360 / math.pi
    gl.perspective(fov, WIDTH/2, HEIGHT/2, -WIDTH,
                        WIDTH/2, HEIGHT/2, 0)

    runner.tick()
    scheduler.tick()
    Sidebar.tick()
end
