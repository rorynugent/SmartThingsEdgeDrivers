local cosock = require("cosock")
local socket = cosock.socket

local json = require "dkjson"
local log = require "log"

local tempest_table = {}

tempest_table.station = {}
tempest_table.hub = {}
tempest_table.current = {}

local function update_current(weatherdata)
    local obj, pos, err = json.decode(weatherdata, 1, nil)

    if( string.match(obj.type, "hub_status") )
    then
        -- Hub status event
        log.trace("hub status event")

        tempest_table.hub.serial_number = { value = weatherdata.serial_number }
        tempest_table.hub.firmware_rev  = { value = weatherdata.firmware_revision}
        tempest_table.hub.uptime        = { value = weatherdata.uptime }
        tempest_table.rssi              = { value = weatherdata.rssi }
    else
        -- Other event
        log.trace("Other event")
    end

    log.debug(weatherdata)
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
                update_current(data)
            end
        until not data
    end)

    cosock.run()

    return
end
