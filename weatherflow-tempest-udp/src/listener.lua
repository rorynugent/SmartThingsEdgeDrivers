--[[
    Copyright 2023 Rory Nugent
    
    DESCRIPTION

    SmartThings Edge Driver for the WeatherFlow Tempest weather station.
    This driver listens on the local network for broadcast UDP packets from the hub, parses them,
    and communicates relevant data to the SmartThings hub

    NOTE

    This driver assumes the following:
    * The WeatherFlow Tempest hub is on the same network as your SmartThings hub
    * Clients on the network are not isolated and can receive traffic from other clients, e.g. guest network
    * Assumes ingestion of v171 of the UDP reference from WeatherFlow: https://weatherflow.github.io/Tempest/api/udp/v171/

--]]
local cosock = require("cosock")
local socket = cosock.socket

local json = require "dkjson"

local log = require "log"
--log.set_log_level("debug")

local tempest_table = {}

tempest_table.hub = {}
tempest_table.device = {}
tempest_table.current = {}

local function parse_payload(weatherdata)
    local obj, pos, err = json.decode(weatherdata, 1, nil)

    -- Hub status event
    if ( string.match(obj.type, "hub_status") )
    then
        log.trace("Hub status event")

        tempest_table.hub.serial_number = { value = obj.serial_number }
        tempest_table.hub.firmware_rev  = { value = obj.firmware_revision}
        tempest_table.hub.uptime        = { value = obj.uptime }
        tempest_table.hub.rssi          = { value = obj.rssi }

        log.info(
            string.format('HUB STATUS EVENT - Serial Number: \"%s\", Firmware: %d, Uptime: %d, RSSI: %d',
            tempest_table.hub.serial_number.value,
            tempest_table.hub.firmware_rev.value,
            tempest_table.hub.uptime.value,
            tempest_table.hub.rssi.value)
        )
    -- Device status event
    elseif ( string.match(obj.type, "device_status") )
    then
        log.trace("Device status event")

        tempest_table.device.serial_number  = { value = obj.serial_number }
        tempest_table.device.hub_sn         = { value = obj.hub_sn }
        tempest_table.device.timestamp      = { value = obj.timestamp }
        tempest_table.device.uptime         = { value = obj.uptime }
        tempest_table.device.voltage        = { value = obj.voltage }
        tempest_table.device.firmware_rev   = { value = obj.firmware_revision }
        tempest_table.device.rssi           = { value = obj.rssi }
        tempest_table.device.hub_rssi       = { value = obj.hub_rssi }

        log.info(
            string.format('DEVICE STATUS EVENT - Serial Number: \"%s\", Firmware: %d, Voltage: %.2f, Uptime: %d, RSSI: %d',
            tempest_table.device.serial_number.value,
            tempest_table.device.firmware_rev.value,
            tempest_table.device.voltage.value,
            tempest_table.device.uptime.value,
            tempest_table.device.rssi.value)
        )
    -- Observation Tempest event
    elseif ( string.match(obj.type, "obs_st") )
    then
        log.trace("Tempest observation event")

        -- Lua index starts at 1
        tempest_table.current.timestamp     = { value = obj.obs[1][1] }
        tempest_table.current.wind_lull     = { value = obj.obs[1][2] }
        tempest_table.current.wind_avg      = { value = obj.obs[1][3] }
        tempest_table.current.wind_gust     = { value = obj.obs[1][4] }
        tempest_table.current.wind_dir      = { value = obj.obs[1][5] }
        --tempest_table.current.wind_int    = { value = obj.obs[1][6] }
        tempest_table.current.pressure      = { value = obj.obs[1][7] }
        tempest_table.current.celsius       = { value = obj.obs[1][8] }
        tempest_table.current.humidity      = { value = obj.obs[1][9] }
        tempest_table.current.lux           = { value = obj.obs[1][10] }
        tempest_table.current.uv            = { value = obj.obs[1][11] }
        tempest_table.current.solar         = { value = obj.obs[1][12] }
        tempest_table.current.rain_mm       = { value = obj.obs[1][13] }
        tempest_table.current.precip        = { value = obj.obs[1][14] }
        tempest_table.current.lightning_avg = { value = obj.obs[1][15] }
        tempest_table.current.lightning_cnt = { value = obj.obs[1][16] }
        tempest_table.current.battery_v     = { value = obj.obs[1][17] }
        --tempest_table.current.interval_mins = { value = obj.obs[1][18] }

        log.info(
            string.format('OBSERVATION EVENT - Temperature: %.2f°C, Humidity: %.2f%% RH, Pressure: %.2f MB, Wind Avg: %.2f m/s, UV Index: %.2f',
            tempest_table.current.celsius.value,
            tempest_table.current.humidity.value,
            tempest_table.current.pressure.value,
            tempest_table.current.wind_avg.value,
            tempest_table.current.uv.value)
        )
    -- Rain start event
    elseif ( string.match(obj.type, "evt_precip") )
    then
        log.trace("Rain start event")
    -- Lightning strike event
    elseif ( string.match(obj.type, "evt_strike") )
    then
        log.trace("Lightning strike event")
    -- Rapid wind event
    elseif ( string.match(obj.type, "rapid_wind") )
    then
        log.trace("Rapid wind event")
    -- Observation air event
    elseif ( string.match(obj.type, "obs_air") )
    then
        log.trace("Air observation event")
    else
        -- Other event
        log.trace("Other event")
        log.debug(weatherdata)
    end

    --log.debug(weatherdata)
end

return function(driver)

    cosock.spawn(function ()
        local port = 50222
        local addr = "0.0.0.0"

        log.debug("Starting server thread...")

        local sock = assert(socket.udp())
        sock:settimeout(30)

        local ok, err = sock:setsockname(addr, port)
        if not ok then
            log.error("Failed to bind server: " .. err)
            return
        end

        log.info("Server running on 0.0.0.0 and listening on port 50222")

        repeat
            local data, ip, port = sock:receivefrom(1024)
            if data then
                parse_payload(data)
            end
        until not data
    end, "listener")

    cosock.run()

    log.debug("Cosock finished")

    return
end
