keyjoy
======

A lua library for the Awesome WM that changes XInput device
properties based on rules configured by the user.

Description
-----------

Keyjoy uses the awful.rules system to match clients. If a 
client matches a rule with a property *keyjoy* then it will
apply any changed properties to matching devices. Devices
are matched with the lua string.match function, but property
names must be exact. Keyjoy currently relies on xinput to 
change the properties, so ensure you have this utility
installed. See xinput(1) for more details.

Usage
-----

The keyjoy property should be in this structure:

    keyjoy = {
        ["Device 1"] = {
            ["Property 1"] = {
                [3] = 3.0000,
                [5] = 4.0000}
            ["Property 2"] = {
                [3] = 0 }
            ["Property 3"] = {1, 3, 1, 1}}
        ["Device 2"] {
            ["Property 1"]= {2}
            ["Property 2"] = {
                [4] = 2 }}}
                
Add to your rc.lua file by placing the keyjoy property in a rule

    awful.rules.rules = {
        { rule = { class = "xterm" },
            properties = { tag = tags[1], keyjoy = keyjoy } }
    }
    
Example
-------

    keyjoy_chromium = {
        ["3Dconnexion"] = {
            ["Axis Keys (low)"] = {
                [9]=105,    --Zdown = Ctrl -
                [10]=20,
                [21]=105,   --ZRCCW = Ctrl PgDown
                [22]=117 
            },
            ["Axis Keys (high)"] = {
                [9]=105,    --Zup = Ctrl +
                [10]=21,
                [21]=105,   --ZRCW = Ctrl PgUp
                [22]=112 
            },
            ["Axis Mapping"] = {
                [3]=6,      --Z = key
                [6]=6       --ZR = key
            },
            ["Axis Type"] = {
                [3]=1,      --Z = relative
                [6]=1       --ZR = relative
            },
            ["Axis Deadzone"] = {
                [3]=16000,  --Z = key
                [6]=16000   --ZR = key
            }
        }
    }
    -- {{{ Rules
    awful.rules.rules = {
        -- All clients will match this rule.
        { rule = { },
          properties = { border_width = beautiful.border_width,
                         border_color = beautiful.border_normal,
                         focus = awful.client.focus.filter,
                         keys = clientkeys,
                         buttons = clientbuttons } },
        { rule = { class = "MPlayer" },
          properties = { floating = true } },
        { rule = { class = "pinentry" },
          properties = { floating = true } },
        { rule = { class = "Gimp" },
          properties = { floating = true } },
        -- Execute the chromium placement function.
        { rule = { class = "Chromium-browser", instance = "Chromium-browser" },
          properties = { tag = tags["www"], keyjoy = keyjoy_chromium } },
        -- Set Pidgin to always map on tags number 1 of screen 1.
        { rule = { class = "Pidgin" },
          properties = { tag = tags["im"] } }
    }
    -- }}}
