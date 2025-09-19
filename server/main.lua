local ESX = exports['es_extended']:getSharedObject()
local vehiclesByPlate = {} -- plate -> entity

local function getIdentifier(src)
  local xPlayer = ESX.GetPlayerFromId(src)
  return xPlayer and xPlayer.getIdentifier() or nil
end

-- ดึงรายการรถของผู้เล่นในโรง/impound
lib.callback.register('esx_garage:getPlayerVehicles', function(source, garageId)
  local identifier = getIdentifier(source)
  if not identifier then return {} end
  local rows = MySQL.query.await([[
    SELECT plate, vehicle, stored, impounded, impound_fee, impound_until, garage_id
    FROM owned_vehicles WHERE owner = ?
  ]], { identifier })
  for i=1, #rows do rows[i].vehicle = json.decode(rows[i].vehicle or '{}') end
  return rows
end)

-- รายการรถถูกยึดของผู้เล่น
lib.callback.register('esx_garage:getImpounded', function(source)
  local identifier = getIdentifier(source); if not identifier then return {} end
  return MySQL.query.await('SELECT plate, impound_fee FROM owned_vehicles WHERE owner = ? AND impounded = 1', { identifier })
end)

-- ไถ่ถอน
lib.callback.register('esx_garage:releaseImpound', function(source, plate, targetGarage)
  local identifier = getIdentifier(source); if not identifier then return { ok=false, reason='noid' } end
  local row = MySQL.single.await('SELECT impounded, impound_fee FROM owned_vehicles WHERE owner = ? AND plate = ?', { identifier, plate })
  if not row or row.impounded ~= 1 then return { ok=false, reason='notimp' } end

  -- ชำระเงินผ่าน ESX (เงินสด)
  local xPlayer = ESX.GetPlayerFromId(source)
  if xPlayer.getMoney() < row.impound_fee then return { ok=false, reason='nomoney' } end
  xPlayer.removeMoney(row.impound_fee)

  local ok = MySQL.update.await('UPDATE owned_vehicles SET impounded = 0, stored = 1, garage_id = ? WHERE owner = ? AND plate = ?',
    { targetGarage or Config.Impound.GarageId, identifier, plate })
  return ok == 1 and { ok=true } or { ok=false, reason='dberr' }
end)

-- สปอว์นจากฝั่งเซิร์ฟเวอร์ด้วย ServerSetter เพื่อความเสถียร และกันดิวปลิด้วย stored flag
lib.callback.register('esx_garage:spawnFromServer', function(source, data)
  local identifier = getIdentifier(source); if not identifier then return { ok=false, reason='noid' } end
  local plate, model, garageId = data.plate, data.model, data.garageId
  if not plate or not model then return { ok=false, reason='badargs' } end

  local row = MySQL.single.await('SELECT stored, impounded, vehicle FROM owned_vehicles WHERE owner = ? AND plate = ?', { identifier, plate })
  if not row then return { ok=false, reason='notfound' } end
  if row.impounded == 1 then return { ok=false, reason='impounded' } end
  if row.stored ~= 1 then return { ok=false, reason='alreadyOut' } end

  -- race-safe mark out
  local changed = MySQL.update.await('UPDATE owned_vehicles SET stored = 0, garage_id = ? WHERE owner = ? AND plate = ? AND stored = 1', { garageId, identifier, plate })
  if changed ~= 1 then return { ok=false, reason='race' } end

  local c = data.coord
  local veh = CreateVehicleServerSetter(joaat(model), c.x, c.y, c.z, c.w)
  if veh == 0 then
    -- rollback
    MySQL.update.await('UPDATE owned_vehicles SET stored = 1 WHERE owner = ? AND plate = ?', { identifier, plate })
    return { ok=false, reason='spawnfail' }
  end

  -- ตั้งค่าเริ่มต้น
  SetVehicleNumberPlateText(veh, plate)
  Entity(veh).state:set('isGarageVehicle', true, true)
  Entity(veh).state:set('owner', identifier, true)
  Entity(veh).state:set('plate', plate, true)
  vehiclesByPlate[plate] = veh

  return { ok=true }
end)

-- เก็บรถ: mark stored=true
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

-- ตรวจจับการลบ entity เพื่อ impound อัตโนมัติ
AddEventHandler('entityRemoved', function(ent)
  if not ent or not DoesEntityExist(ent) then return end -- ป้องกันกรณี entity ชำรุด
  local e = Entity(ent)
  if e and e.state and e.state.isGarageVehicle and e.type == 2 then -- 2 = vehicle
    local plate = e.state.plate
    if plate then
      MySQL.update.await('UPDATE owned_vehicles SET impounded = 1, impound_fee = GREATEST(IFNULL(impound_fee,0), ?) WHERE plate = ? AND stored = 0',
        { Config.Impound.MinFee, plate })
      vehiclesByPlate[plate] = nil
    end
  end
end)

-- คำสั่งแอดมิน/ตำรวจ
ESX.RegisterCommand('impoundveh', 'admin', function(xPlayer, args)
  local plate = args.plate; local fee = math.min(Config.Impound.MaxFee, math.max(Config.Impound.MinFee, args.fee or Config.Impound.MinFee))
  MySQL.update.await('UPDATE owned_vehicles SET impounded = 1, impound_fee = ? WHERE plate = ?', { fee, plate })
  xPlayer.showNotification(('ยึดรถ %s ค่าธรรมเนียม %d'):format(plate, fee))
end, true, { help = 'Impound vehicle by plate', validate = true, arguments = { { name='plate', type='string' }, { name='fee', type='number', optional=true } } })

ESX.RegisterCommand('unimpoundveh', 'admin', function(xPlayer, args)
  local plate = args.plate
  MySQL.update.await('UPDATE owned_vehicles SET impounded = 0, stored = 1 WHERE plate = ?', { plate })
  xPlayer.showNotification(('คืนสภาพยึดรถ %s'):format(plate))
end, true, { help = 'Release vehicle from impound', validate = true, arguments = { { name='plate', type='string' } } })
