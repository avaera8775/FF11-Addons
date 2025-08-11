_addon.name = 'di'
_addon.version = '0.1'
_addon.author = 'MelioraXI'
_addon.commands = {'di'}

--[[

**CREDIT** 
Aphung:  for creating the addon and, providing the API for the orginal addon -> https://github.com/aphung/whereisdi
Loonies: for making Ashita version which inspired this addon.

**Description**
This addon will not submit DI data, instead this addon will just pull latest location.
Server is automatically set based on logged-in character but can be set manually if needed.

]]

config = require('config')
json = require('libs.json')
http = require('socket.http')
ltn12 = require('libs.ltn12')
res = require('resources')

defaults = {
    server = '',
    apiToken = 'Bearer 82j1GCjQxUCxriN-XhXicb6Ts8G400l7',
}

settings = config.load(defaults)

function iso8601_to_unix(str)
    if type(str) ~= 'string' then return nil end
    local y, m, d, h, min, s = str:match('^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)')
    return os.time({year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = tonumber(h), min = tonumber(min), sec = tonumber(s)})
end

function fetchDiApi()
    response_body = {}
    local _, status = http.request {
        url = 'https://api.whereisdi.com/items/di?fields=*.*',
        method = 'GET',
        headers = {
            ['Authorization'] = settings.apiToken,
            ['Accept'] = 'application/json'
        },
        sink = ltn12.sink.table(response_body)
    }

    --[[
    
    if status ~= 200 then
        windower.add_to_chat(123, '[whereisdi] API HTTP error: ' .. tostring(status))
        return nil
    end

    ]]

    return table.concat(response_body)
end

function printStatus(filter_server)
    local raw = fetchDiApi()
    if not raw then return end

    local decoded, pos, err = json.decode(raw)
    if not decoded or not decoded.data then
        --windower.add_to_chat(123, '[whereisdi] Failed to decode JSON: ' .. tostring(err))
        return
    end

    local found = false
    for _, entry in ipairs(decoded.data) do
        local server = entry.server and entry.server.name or 'Unknown'
        if not filter_server or server:lower() == filter_server:lower() then
            found = true
            local status = '(no info)'
            if type(entry.location) == 'table' and entry.location.en_us then
                status = entry.location.en_us
            end

            local ago = ''
            if entry.date_updated then
                local updated_unix = iso8601_to_unix(entry.date_updated)
                if updated_unix then
                    local now = os.time()
                    local diff = now - updated_unix
                    if diff < 60 then
                        ago = '(just now)'
                    else
                        local mins = math.floor(diff / 60)
                        ago = string.format('(%d minute%s ago)', mins, mins == 1 and '' or 's')
                    end
                end
            end

            windower.add_to_chat(207, string.format('[DI] %s: %s %s', server, status, ago))
        end
    end

    if filter_server and not found then
        windower.add_to_chat(123, '[DI] No info found for server: ' .. filter_server)
    end
end

function get_current_server_name()
    local server_id = windower.ffxi.get_info().server
    if server_id and res.servers[server_id] then
        return res.servers[server_id].name
    else
        windower.add_to_chat(123, '[DI] Not supported on private servers. Unloading addon.')
        windower.send_command('lua unload di') 
        return nil
    end
end

windower.register_event('addon command', function(command, ...)
    local args = {...}
    command = command and command:lower() or ''

    if command == 'setserver' then
        if #args < 1 then
            windower.add_to_chat(123, '[DI] Usage: //di setserver <ServerName>')
            return
        end
        local server = table.concat(args, ' ')
        settings.server = server
        config.save(settings)
        windower.add_to_chat(207, '[DI] Server set to: ' .. server)
    else
        local server = settings.server
        if not server or server == '' then
            server = get_current_server_name()
            if server then
                settings.server = server
                config.save(settings)
                windower.add_to_chat(207, '[DI] Server automatically set to: ' .. server)
            else
                windower.add_to_chat(123, '[DI] Unable to detect server. Use //di setserver YourServer')
                return
            end
        end
        printStatus(server)
    end
end)