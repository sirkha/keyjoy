-----------------------------------------------------------------
-- @author John C Kha
-- @copyright 2014
-- @release 3.6.0
-----------------------------------------------------------------
-- Modify the behavior of an input device on a per-client
-- basis using xinput. See the xinput manpage for more details.
-- Use awful.rules to set the properties.
-- EXAMPLE
--  awful.rules.rules = {
--      {rule = { client = "chromium browser"},
--       properties = { tag=tags[1],
--          keyjoy = { ["3Dconnexion"] = { ["Axis Type"] = {[3] = 1}, ["Axis Mapping"] = {[3] = 1}}}
--                     }
--      }
--  }
--  This changes the 3rd values of the Axis Type and Axis Mapping properties to 1 on
--  any device who's name includes 3Dconnexion.
-- The keyjoy property should be in this structure:
--  keyjoy = {
--      ["Device 1"] = {
--          ["Property 1"] = {
--              [3] = 3.0000,
--              [5] = 4.0000}
--          ["Property 2"] = {
--              [3] = 0 }
--          ["Property 3"] = {1, 3, 1, 1}}
--      ["Device 2"] {
--          ["Property 1"]= {2}
--          ["Property 2"] = {
--              [4] = 2 }}}
-- --------------------------------------------------------------
local capi = {
    client = client
}
local awful = require("awful")
local naughty = require("naughty")

-- Uses xinput to read the properties of the specified device. Returns
-- a table with the properties.
local active_mods = {}
local debug = 0

local function readprops(device) 
    local props_text = awful.util.pread("xinput list-props " .. device)
    local props = {id=device, name=props_text:match("Device '(.-)'"), properties={}}
    for line in props_text:gmatch("[^\n]+") do
        local prop_name, prop_num, v = line:match("%s*(.-) %((%d%d%d)%):%s*(.+)")
        if v then
            v = " " .. v..","
            sep = v:gsub(" [^,]*,", " ([^,]*),")
            prop_values = {v:match(sep)}
            props.properties[prop_name] = {number=prop_num, values=prop_values}
        end
    end
    outprops = ""
    for k, t in pairs(props.properties) do
        outprops = outprops .. k .. "|" .. t.number
        for m, l in pairs(t.values) do
            outprops = outprops .. " " .. m..":"..l
        end
        outprops=outprops .."\n"
    end
    if debug > 1 then
        if not props_text then
            props_text = [[
No properties returned.
Please insure you have xinput installed and that the command
'xinput list-props id', where id is a valid device id returns 
a list of device properties.
]]
        end
        naughty.notify({title = "KeyJoy Debug", text = props_text, timeout = 0})
        
    end
    return props
end

local function readdevs()
    local devs_text = awful.util.pread("xinput list --id-only")
    local devs={}
    for line in devs_text:gmatch("[^\n]+") do
        devs[line + 0] = awful.util.pread("xinput list --name-only " .. line)
    end
    if debug > 1 then
        local list
        for id, name in pairs(devs) do
            list = id .. "\t" .. name .. "\n"
        end
        if not list then
            list = [[
No devices returned.
Please insure you have xinput installed and that the command
'xinput list --id-only' returns a list of device ids.
]]
        end
        naughty.notify({title = "KeyJoy Debug", text = list, timeout = 0})
        
    end
    return devs
end

function activate(c) 
    --Get rules matching client
    local prop_mods
    for i, rule in pairs(awful.rules.matching_rules(c,awful.rules.rules)) do
        --Get any keyjoy properties. The last one to match will be applied.
        prop_mods = rule.properties.keyjoy or prop_mods
    end
    --Check if any matching rules contain a keyjoy property
    if prop_mods then
        local devices = readdevs()
        for dev_match, props in pairs(prop_mods) do
            local dev_matches
            for dev_id, dev_name in pairs(devices) do
                local initial_props
                if dev_name:match(dev_match) then
                    dev_matches = true
                    local command_exec
                    initial_props = readprops(dev_id)
                    --Match properties and change values.
                    for prop, values in pairs(props) do
                        if initial_props.properties[prop] then
                            local prop_num = initial_props.properties[prop].number
                            local dev_values = initial_props.properties[prop].values
                            local mod_values = {}
                            local value_matches
                            for val_id, val in pairs(dev_values) do
                                if values[val_id] and not (values[val_id] .. "" == val) then
                                    value_matches = true
                                    mod_values[val_id] = values[val_id]
                                else
                                    mod_values[val_id] = val
                                end
                            end
                            if value_matches then
                                local cmd = "xinput set-prop " .. dev_id .. " " .. prop_num
                                for val_id, val in pairs(mod_values) do
                                    cmd = cmd .. " " .. val
                                end
                                local result = awful.util.pread(cmd)
                                command_exec = true
                                if debug > 0 and not (result == "") then
                                    naughty.notify({title = "KeyJoy", text = result, timeout = 5})
                                end
                            end
                        elseif debug > 0 then
                            naughty.notify({title = "KeyJoy", text = "Property '"
                                .. prop .. "' of device '" .. dev_name .. "' not found.", timeout = 5})
                        end
                    end
                    --If any properties were modified
                    if command_exec then
                        --save initial and final properties
                        active_mods[dev_id] = { initial_props = initial_props, 
                            final_props = readprops(dev_id)}
                    end
                end
            end
            if debug > 0 and not dev_matches then
                naughty.notify({title = "KeyJoy", text = "'" .. dev_match .. 
                    "' did not match any devices.", timeout = 2, screen = c.screen})
            end
        end
    end
end

function deactivate(c)
    for dev_id, props in pairs(active_mods) do
        local current_props = readprops(dev_id).properties
        local initial_props = props.initial_props.properties
        local final_props = props.final_props.properties
        --compare current properties of devices to saved final properties of devices
        for prop, info in pairs(current_props) do
            local prop_num = info.number
            local values = info.values
            local value_matches
            for val_id, val in pairs(values) do
                --if a modified property is the same as current property, 
                -- restore the property to the intiital state
                if (val == final_props[prop].values[val_id]) and not (val == initial_props[prop].values[val_id]) then
                    value_matches = true
                end
            end
            if value_matches then
                cmd = "xinput set-prop " .. dev_id .. " " .. prop_num
                for val_id, val in pairs(initial_props[prop].values) do
                    cmd = cmd .. " " .. val
                end
                result = awful.util.pread(cmd)
                if debug > 0 and not (result == "") then
                    naughty.notify({title = "KeyJoy", text = result, timeout = 5})
                end
            end
        end
    end
    --Clear active mods
    active_mods = {}
end


capi.client.connect_signal("focus", activate)
capi.client.connect_signal("unfocus", deactivate)
