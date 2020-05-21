local utils = require 'mp.utils'
local msg = require 'mp.msg'

-- Splits a string into lines
function spliterator(s)
    if s:sub(-1) ~= "\n" then
        s = s .. "\n"
    end
    return s:gmatch("(.-)\n")
end

function get_sys_value(variable)
    local f = assert(io.open(variable, "r"))
    local val = string.gsub(f:read("*all"), "\n$", "")
    f:close()
    return val
end

function bytes_to_mib_str(b)
    return string.format("%.2f", b / 1024 / 1024)
end

local freqgetter = {}

function show_gpu_freq(card)
    local vendor = identify_card(card)
    if(vendor == nil) then
        mp.osd_message("Could not identify GPU vendor for card " .. card)
        return
    end
    local frequencies = freqgetter[vendor](freqgetter, card)
    display_gpu_freq(frequencies)
end

function card_path(card)
   return "/sys/class/drm/" .. card .. "/"
end

function identify_card(card)
    local fi = utils.file_info(card_path(card) .. "gt_act_freq_mhz")
    -- I don't remember if intel has the vendor value h-haha
    if(fi ~= nil and fi.is_file) then
        return "intel"
    end
    vendor = get_sys_value(card_path(card) .. "device/vendor")
    if(vendor == "0x1002") then
        return "amd"
    end
    return nil
end

function freqgetter:intel(card)
    local freq_cur = get_sys_value(card_path(card) .. "gt_act_freq_mhz")
    local freq_max = get_sys_value(card_path(card) .. "gt_max_freq_mhz")
    local freq_req = get_sys_value(card_path(card) .. "gt_cur_freq_mhz")
    return {["core"] = {cur = freq_cur, max = freq_max, req = freq_req}}
end

--[[ YOU HAVE ENTERED THE CURSED AMD ZONE ]]--

-- Returns the parsed frequencies from an AMD card
function amd_pp_consumer(val)
    local fmax = 0
    local fcur = 0
    for line in spliterator(val) do
        local freq = tonumber(line:match("%d: (%d+)Mhz"))
        local is_cur = line:match("%*")
        if is_cur ~= nil then
            fcur = freq
        end
        if freq > fmax then
            fmax = freq
        end
    end
    return fcur, fmax
end

function freqgetter:amd(card)
    local scuffed = get_sys_value(card_path(card) .. "device/pp_dpm_sclk")
    local scuffedmem = get_sys_value(card_path(card) .. "device/pp_dpm_mclk")
    --local core_cur, core_max = amd_pp_consumer(scuffed)
    local cur, max = amd_pp_consumer(scuffed)
    local core = {["cur"] = cur, ["max"] = max}
    local cur_mem, max_mem = amd_pp_consumer(scuffedmem)
    local mem = {["cur"] = cur_mem, ["max"] = max_mem,
                 ["used"] = tonumber(get_sys_value(card_path(card) .. "device/mem_info_vram_used")),
                 ["total"] = tonumber(get_sys_value(card_path(card) .. "device/mem_info_vram_total"))}
    local link = {
        ["speed"] = get_sys_value(card_path(card) .. "device/current_link_speed"),
        ["width"] = get_sys_value(card_path(card) .. "device/current_link_width")
    }
    return {["core"] = core, ["mem"] = mem, ["link"] = link}
end

--[[ YOU ARE NOW LEAVING THE CURSED AMD ZONE ]]--

function display_gpu_freq(freqs)
    assert(freqs["core"])
    local cfreqs = freqs["core"]
    local msg = "Core: "
        msg = msg .. cfreqs["cur"] .. "/" .. cfreqs["max"] .. " MHz"
    if cfreqs["req"] then
        msg = msg .. " (requested " .. cfreqs["req"] .. " MHz)"
    end
    if freqs["mem"] ~= nil then
        msg = msg .. "\n"
        msg = msg .. "Memory: " .. freqs["mem"]["cur"] .. "/" .. freqs["mem"]["max"] .. " MHz\n"
        msg = msg .. "Memory Usage: " .. bytes_to_mib_str(freqs["mem"]["used"]) .. "/"
        msg = msg .. bytes_to_mib_str(freqs["mem"]["total"]) .. " MiB"
    end
    if freqs["link"] ~= nil then
        msg = msg .. "\n"
        msg = msg .. "Link: " .. freqs["link"]["speed"] .. " x" .. freqs["link"]["width"]
    end
    mp.osd_message(msg)
end

mp.register_script_message("show-gpu-freq", show_gpu_freq)
