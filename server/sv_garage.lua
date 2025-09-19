local ESX = exports['es_extended']:getSharedObject()
local VEH_TABLE = Config.VehicleTable

lib.callback.register('esx_nfs_garage:list', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end
    local identifier = xPlayer.getIdentifier()
    local rows = MySQL.query.await(('SELECT plate, vehicle, stored, garage_id FROM `%s` WHERE owner = ? ORDER BY updated_at DESC'):format(VEH_TABLE), { identifier })
    if Config.Debug then
        print(('[GARAGE] list %s rows for %s'):format(#rows, identifier))
    end
    return rows or {}
end)

RegisterNetEvent('esx_nfs_garage:switch', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier = xPlayer.getIdentifier()
    local plate = data and data.plate
    local garageId = data and data.garageId
    if type(plate) ~= 'string' then
        if Config.Debug then print('[GARAGE] invalid plate') end
        return
    end

    local row = MySQL.single.await(('SELECT plate, vehicle FROM `%s` WHERE owner = ? AND plate = ? LIMIT 1'):format(VEH_TABLE), { identifier, plate })
    if not row then
        if Config.Debug then print(('[GARAGE] not owner plate %s'):format(plate)) end
        return
    end

    -- อัปเดต stored flag: เก็บคันเดิมเป็น stored=1 และปล่อยคันใหม่ stored=0
    MySQL.update.await(('UPDATE `%s` SET stored = 1 WHERE owner = ? AND stored = 0'):format(VEH_TABLE), { identifier })
    MySQL.update.await(('UPDATE `%s` SET stored = 0, garage_id = ?, updated_at = CURRENT_TIMESTAMP WHERE owner = ? AND plate = ?'):format(VEH_TABLE), { garageId, identifier, plate })

    if Config.Debug then
        print(('[GARAGE] switch request %s -> %s'):format(identifier, plate))
    end

    -- ส่งข้อมูลยานพาหนะไปให้ client สร้าง
    TriggerClientEvent('esx_nfs_garage:spawn', src, {
        plate = row.plate,
        props = json.decode(row.vehicle or '{}'),
        garageId = garageId
    })
end)
