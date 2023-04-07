-- Edge libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local log = require "log"

local listener = require "listener"

local function device_init(drver, device)
    log.info('device_init' .. device.id)
end

local function device_added(driver, device)
    log.info('device_added' .. device.id)
end

local function device_removed(driver, device)
    log.info('device_removed' .. device.id)
end

local function info_changed(driver, device)
    log.info('info_changed' .. device.id)
end


-- Driver configuration
local driver = Driver("weatherflow-tempest-udp", {
    lifecycle_handlers = {
        init = device_init,
        added = device_added,
        removed = device_removed,
        infoChanged = info_changed,
    },
})

-- Driver run
log.info('WeatherFlow Tempest UDP started')

listener(driver)
driver:run()

log.warn('Existing weatherflow-tempest-udp')
