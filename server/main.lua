local ESX = exports['es_extended']:getSharedObject()

local function getIdentifier(src)
  local xPlayer = ESX.GetPlayerFromId(src)
  return xPlayer and xPlayer.getIdentifier() or nil
end

lib.callback.register('esx_garage:getPlayerVehicles', function(source, garageId)
  local identifier = getIdentifier(source)
  if not identifier then return {} end

  local query = [[
    SELECT plate, vehicle, stored, impounded, impound_fee, impound_until, garage_id
    FROM owned_vehicles
    WHERE owner = ? AND (garage_id IS NULL OR garage_id = ?)
  ]]
  local rows = MySQL.query.await(query, { identifier, garageId })
  for i=1, #rows do
    rows[i].vehicle = json.decode(rows[i].vehicle or '{}')
  end
  return rows
end)

-- เก็บรถ: อัปเดต stored=true และบันทึก garage_id
RegisterNetEvent('esx_garage:storeVehicle', function(plate, garageId)
  local src = source
  local identifier = getIdentifier(src); if not identifier then return end

  local updated = MySQL.update.await(
    'UPDATE owned_vehicles SET stored = 1, garage_id = ?, impounded = 0 WHERE owner = ? AND plate = ?',
    { garageId, identifier, plate }
  )
  if updated > 0 then
    TriggerClientEvent('esx_garage:notify', src, ('เก็บรถ %s แล้ว'):format(plate))
  else
    TriggerClientEvent('esx_garage:notify', src, 'ไม่พบรถหรือไม่มีสิทธิ์')
  end
end)

-- ขอสิทธิ์สปอว์น: กันดิวปลิด้วย stored flag
lib.callback.register('esx_garage:requestSpawn', function(source, plate, garageId)
  local identifier = getIdentifier(source); if not identifier then return { ok=false, reason='noid' } end
  local row = MySQL.single.await('SELECT stored, impounded FROM owned_vehicles WHERE owner = ? AND plate = ? AND (garage_id IS NULL OR garage_id = ?)', { identifier, plate, garageId })
  if not row then return { ok=false, reason='notfound' } end
  if row.impounded == 1 then return { ok=false, reason='impounded' } end
  if row.stored ~= 1 then return { ok=false, reason='alreadyOut' } end

  -- mark out
  local ok = MySQL.update.await('UPDATE owned_vehicles SET stored = 0 WHERE owner = ? AND plate = ? AND stored = 1', { identifier, plate })
  if ok == 1 then
    return { ok=true }
  else
    return { ok=false, reason='race' }
  end
end)

-- สำหรับแอดมิน: ย้าย/คืน/ยึดรถ (ตัวอย่างยึด)
ESX.RegisterCommand('impoundveh', 'admin', function(xPlayer, args)
  local plate = args.plate; local fee = args.fee or 1000
  MySQL.update.await('UPDATE owned_vehicles SET impounded = 1, impound_fee = ? WHERE plate = ?', { fee, plate })
  xPlayer.showNotification(('ยึดรถ %s เรียบร้อย'):format(plate))
end, true, { help = 'Impound vehicle by plate', validate = true, arguments = { { name='plate', type='string' }, { name='fee', type='number', optional=true } } })
