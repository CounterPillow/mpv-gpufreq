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

local freqgetter = {}

function show_gpu_freq(card)
    local vendor = identify_card(card)
    if(vendor == nil) then
        mp.osd_message("Could not identify GPU vendor for card " .. card)
        return
    end
    local freq_cur, freq_max, freq_req = freqgetter[vendor](freqgetter, card)
    display_gpu_freq(freq_cur, freq_max, freq_req)
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
    return freq_cur, freq_max, freq_req
end

function freqgetter:amd(card)
    local scuffed = get_sys_value(card_path(card) .. "device/pp_dpm_sclk")
    local fmax = 0
    local fcur = 0
    for line in spliterator(scuffed) do
        local freq = tonumber(line:match("%d: (%d+)Mhz"))
        local is_cur = line:match("%*")
        if is_cur ~= nil then
            fcur = freq
        end
        if freq > fmax then
            fmax = freq
        end
    end
    return fcur, fmax, nil
end

function display_gpu_freq(freq_cur, freq_max, freq_req)
    if freq_req == nil then
        mp.osd_message(freq_cur .. "/" .. freq_max .. " MHz")
    else
        mp.osd_message(freq_cur .. "/" .. freq_max .. " MHz (requested " .. freq_req .. " MHz)")
    end
end

mp.register_script_message("show-gpu-freq", show_gpu_freq)
