local ESX = exports['es_extended']:getSharedObject()

local function getIdentifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.getIdentifier() or nil
end

local function hasJob(src, jobs)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local j = xPlayer.job and xPlayer.job.name or nil
    if not j then return false end
    for _, name in ipairs(jobs or {}) do
        if name == j then return true end
    end
    return false
end

local function isPlateValid(plate)
    return plate and plate:match('^%u%u%u %d%d%d$') ~= nil
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

lib.callback.register('esx_garage:getPlayerVehicles', function(source, garageId)
    local identifier = getIdentifier(source)
    if not identifier then return {} end

    local rows = MySQL.query.await([[
        SELECT plate, vehicle, stored, impounded, impound_fee, impound_until, garage_id
        FROM owned_vehicles
        WHERE owner = ? AND (garage_id IS NULL OR garage_id = ?)
    ]], { identifier, garageId })

    for i = #rows, 1, -1 do
        local v = rows[i]
        v.vehicle = json.decode(v.vehicle or '{}')
        -- จำกัดเฉพาะรถ type = car ถ้ามี field; หากไม่มีถือว่า car
        if v.vehicle and v.vehicle.type and v.vehicle.type ~= 'car' then
            table.remove(rows, i)
        end
    end
    return rows
end)

lib.callback.register('esx_garage:getImpoundVehicles', function(source)
    local identifier = getIdentifier(source)
    if not identifier then return {} end
    local rows = MySQL.query.await([[
        SELECT plate, vehicle, impounded, impound_fee FROM owned_vehicles
        WHERE owner = ? AND impounded = 1
    ]], { identifier })
    for i = 1, #rows do
        rows[i].vehicle = json.decode(rows[i].vehicle or '{}')
    end
    return rows
end)

-- เก็บรถ
lib.callback.register('esx_garage:storeVehicle', function(source, plate, garageId)
    local identifier = getIdentifier(source)
    if not identifier then return { ok = false, reason = 'noid' } end
    plate = string.upper(plate or '')
    if not isPlateValid(plate) then return { ok=false, reason='plate' } end

    local updated = MySQL.update.await(
        'UPDATE owned_vehicles SET stored = 1, garage_id = ?, impounded = 0 WHERE owner = ? AND plate = ?',
        { garageId, identifier, plate }
    )
    return (updated > 0) and { ok=true } or { ok=false, reason='notfound' }
end)

-- ขอสิทธิ์สปอว์น: กันดิวปลิด้วย stored flag
lib.callback.register('esx_garage:requestSpawn', function(source, plate, garageId)
    local identifier = getIdentifier(source)
    if not identifier then return { ok=false, reason='noid' } end
    plate = string.upper(plate or '')
    if not isPlateValid(plate) then return { ok=false, reason='plate' } end

    local row = MySQL.single.await([[
        SELECT stored, impounded FROM owned_vehicles
        WHERE owner = ? AND plate = ? AND (garage_id IS NULL OR garage_id = ?)
    ]], { identifier, plate, garageId })
    if not row then return { ok=false, reason='notfound' } end
    if row.impounded == 1 then return { ok=false, reason='impounded' } end
    if row.stored ~= 1 then return { ok=false, reason='alreadyOut' } end

    local ok = MySQL.update.await([[
        UPDATE owned_vehicles SET stored = 0
        WHERE owner = ? AND plate = ? AND stored = 1
    ]], { identifier, plate })
    if ok == 1 then
        return { ok=true }
    else
        return { ok=false, reason='race' }
    end
end)

-- Auto-impound เมื่อรถหาย/พัง
RegisterNetEvent('esx_garage:autoImpound', function(plate)
    plate = string.upper(plate or '')
    if not isPlateValid(plate) then return end
    local fee = clamp(Config.Impound.AutoFee or Config.Impound.MinFee, Config.Impound.MinFee, Config.Impound.MaxFee)
    MySQL.update.await(
        'UPDATE owned_vehicles SET impounded = 1, impound_fee = ?, stored = 1, garage_id = ? WHERE plate = ?',
        { fee, Config.Impound.GarageId, plate }
    )
end)

-- ชำระเงินปลดรถจาก impound
lib.callback.register('esx_garage:payRelease', function(source, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return { ok=false, reason='noid' } end
    plate = string.upper(plate or '')
    if not isPlateValid(plate) then return { ok=false, reason='plate' } end

    local row = MySQL.single.await('SELECT impounded, impound_fee FROM owned_vehicles WHERE owner = ? AND plate = ?', { xPlayer.getIdentifier(), plate })
    if not row or row.impounded ~= 1 then return { ok=false, reason='not_impounded' } end

    local fee = clamp(tonumber(row.impound_fee or 0), Config.Impound.MinFee, Config.Impound.MaxFee)
    local account = Config.PayAccount or 'bank'
    -- หักเงิน
    if account == 'money' then
        if xPlayer.getMoney() < fee then return { ok=false, reason='notenough' } end
        xPlayer.removeMoney(fee)
    else
        if xPlayer.getAccount(account).money < fee then return { ok=false, reason='notenough' } end
        xPlayer.removeAccountMoney(account, fee)
    end
    -- ปลด impound และพร้อมสปอว์น
    MySQL.update.await('UPDATE owned_vehicles SET impounded = 0, stored = 1 WHERE owner = ? AND plate = ?', { xPlayer.getIdentifier(), plate })
    return { ok=true }
end)

-- ===== Admin / Police tools =====
ESX.RegisterCommand('impoundveh', 'admin', function(xPlayer, args)
    local fee = clamp(args.fee or (Config.Impound.MinFee), Config.Impound.MinFee, Config.Impound.MaxFee)
    MySQL.update.await('UPDATE owned_vehicles SET impounded = 1, impound_fee = ?, stored = 1, garage_id = ? WHERE plate = ?', { fee, Config.Impound.GarageId, args.plate })
    xPlayer.showNotification(('ยึดรถ %s (fee %d)'):format(args.plate, fee))
end, true, { help = 'Impound by plate', validate = true, arguments = { { name='plate', type='string' }, { name='fee', type='number', optional=true } } })

ESX.RegisterCommand('vrelease', 'admin', function(xPlayer, args)
    MySQL.update.await('UPDATE owned_vehicles SET impounded = 0, stored = 1 WHERE plate = ?', { args.plate })
    xPlayer.showNotification(('ปลดรถ %s'):format(args.plate))
end, true, { help = 'Force release impound', validate = true, arguments = { { name='plate', type='string' } } })

ESX.RegisterCommand('vfind', 'admin', function(xPlayer, args)
    local row = MySQL.single.await('SELECT owner, stored, impounded, garage_id FROM owned_vehicles WHERE plate = ?', { args.plate })
    if not row then
        xPlayer.showNotification('ไม่พบรถ')
        return
    end
    xPlayer.showNotification(('stored=%s impounded=%s garage=%s'):format(row.stored, row.impounded, row.garage_id or 'nil'))
end, true, { help = 'Lookup vehicle by plate', validate = true, arguments = { { name='plate', type='string' } } })

ESX.RegisterCommand('vsetgarage', 'admin', function(xPlayer, args)
    MySQL.update.await('UPDATE owned_vehicles SET garage_id = ? WHERE plate = ?', { args.garage, args.plate })
    xPlayer.showNotification(('ย้าย %s ไป %s'):format(args.plate, args.garage))
end, true, { help = 'Set vehicle garage_id', validate = true, arguments = { { name='plate', type='string' }, { name='garage', type='string' } } })

-- Police-only convenient command
ESX.RegisterCommand('pdimpound', 'user', function(xPlayer, args)
    if not hasJob(xPlayer.source, Config.Impound.Jobs) then
        xPlayer.showNotification('ไม่มีสิทธิ์')
        return
    end
    local fee = clamp(args.fee or Config.Impound.MinFee, Config.Impound.MinFee, Config.Impound.MaxFee)
    MySQL.update.await('UPDATE owned_vehicles SET impounded = 1, impound_fee = ?, stored = 1, garage_id = ? WHERE plate = ?', { fee, Config.Impound.GarageId, args.plate })
    xPlayer.showNotification(('ตำรวจยึด %s (fee %d)'):format(args.plate, fee))
end, true, { help = 'Police impound', validate = true, arguments = { { name='plate', type='string' }, { name='fee', type='number', optional=true } } })
