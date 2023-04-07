--[[
    Copyright 2023 Rory Nugent

    SmartThings Edge Driver - WeatherFlow Tempest UDP
--]]

-- Edge libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local json = require 'dkjson'
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

local function add_device(driver, device_number)
    log.trace('add_devices')

    if device_number == nil then
        log.debug('determining current device count')
        local device_list = driver.device_api.get_device_list()
        device_number = #device_list
    end

    local device_name = 'Button ' .. device_number

    log.debug('adding device ' .. device_name)

    local device_id = new_uuid()

    local device_info = {
        type = 'LAN',
        deviceNetworkId = device_id,
        label = device_name,
        profileReference = 'weatherflow-tempest-udp',
        vendorProvidedName = device_name,
    }

    local device_info_json = json.encode(device_info)
    local success, msg = driver.device_api.create_device(device_info_json)

    if success then
        log.debug('successfully created device')
        return device_name, device_id
    end

    log.error(string.format('unsuccessful create_device %s', msg))

    return nil, nil, msg
end

local function discovery_handler(driver, opts, cont)
    log.trace('discovery handler')

    if cont() then
        local device_list = driver.device_api.get_device_list()
        log.trace('starting discovery')

        if #device_list > 0 then
            log.debug('stopping discovery with ' .. #device_list .. ' devices')
            return
        end

        log.debug('Adding first ' .. driver.NAME .. ' device')
        local device_name, device_id, err = add_device(driver, #device_list)
        if err ~= nil then
            log.error(err)
            return
        end
        log.info('added new device ' .. device_name)
    end
end

-- Driver configuration
local driver = Driver("weatherflow-tempest-udp", {
    discovery = discovery_handler,
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
