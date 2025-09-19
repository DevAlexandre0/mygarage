local ESX = exports['es_extended']:getSharedObject()

-- ===== Utils
local function getIdentifier(src)
  local xPlayer = ESX.GetPlayerFromId(src)
  return xPlayer and xPlayer.getIdentifier() or nil
end
local function isPlateValid(p) return p and p:match('^%u%u%u %d%d%d$') ~= nil end
local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end

-- ===== Active map: plate -> { netId, owner, last=vec3?, ts=ms }
local active = {}

RegisterNetEvent('esx_garage:updateVehiclePos', function(plate, x, y, z, netId)
  local src = source
  plate = string.upper(plate or '')
  if not isPlateValid(plate) then return end
  local id = getIdentifier(src); if not id then return end
  local e = active[plate]; if not e or e.owner ~= id or (netId and e.netId ~= netId) then return end
  e.last = vec3(x, y, z); e.ts = GetGameTimer()
end)

RegisterNetEvent('esx_garage:clearActive', function(plate)
  plate = string.upper(plate or '')
  active[plate] = nil
end)

-- ===== DB helpers
local function readPlayerVehicles(identifier)
  local rows = MySQL.query.await([[
    SELECT plate, vehicle, stored, impounded, impound_fee
    FROM owned_vehicles
    WHERE owner = ?
  ]], { identifier })
  for i=1, #rows do rows[i].vehicle = json.decode(rows[i].vehicle or '{}') end
  return rows
end

-- ===== Callbacks: lists/state
lib.callback.register('esx_garage:getPlayerVehicles', function(source)
  local id = getIdentifier(source); if not id then return {} end
  local rows = readPlayerVehicles(id)
  for _, v in ipairs(rows) do
    if v.impounded == 1 then
      v.state = 'in_impound'
    elseif v.stored == 1 then
      v.state = 'in_garage'
    else
      v.state = active[v.plate] and 'out_garage' or 'in_impound'
    end
  end
  return rows
end)

lib.callback.register('esx_garage:getImpoundedVehicles', function(source)
  local id = getIdentifier(source); if not id then return {} end
  local rows = MySQL.query.await('SELECT plate, vehicle FROM owned_vehicles WHERE owner = ? AND impounded = 1', { id })
  for i=1, #rows do rows[i].vehicle = json.decode(rows[i].vehicle or '{}') end
  return rows
end)

lib.callback.register('esx_garage:getVehicleCoords', function(source, plate)
  plate = string.upper(plate or '')
  local id = getIdentifier(source); if not id then return { ok=false, reason='noid' } end
  local e = active[plate]
  if not e then return { ok=false, reason='not_active' } end
  if e.owner ~= id then return { ok=false, reason='not_owner' } end
  if not e.last then return { ok=false, reason='no_coords' } end
  return { ok=true, coords={ x=e.last.x, y=e.last.y, z=e.last.z } }
end)

-- ===== Store / TakeOut
lib.callback.register('esx_garage:storeVehicle', function(source, plate, status, netId)
  local id = getIdentifier(source); if not id then return { ok=false, reason='noid' } end
  plate = string.upper(plate or ''); if not isPlateValid(plate) then return { ok=false, reason='plate' } end

  local row = MySQL.single.await('SELECT vehicle FROM owned_vehicles WHERE owner = ? AND plate = ?', { id, plate })
  if not row then return { ok=false, reason='notfound' } end

  local vj = json.decode(row.vehicle or '{}') or {}
  if status then
    if status.engine then vj.engineHealth = tonumber(status.engine) end
    if status.body   then vj.bodyHealth   = tonumber(status.body)   end
    if status.fuel   then vj.fuelLevel    = tonumber(status.fuel)   end
  end
  vj.type = vj.type or 'car'

  local ok = MySQL.update.await('UPDATE owned_vehicles SET stored=1, impounded=0, vehicle=? WHERE owner=? AND plate=?',
                                { json.encode(vj), id, plate })
  if ok > 0 then
    -- ลบเอนทิตีฝั่งเซิร์ฟเวอร์อย่างชัดเจนเพื่อลดซาก
    if netId and NetworkDoesNetworkIdExist(netId) then
      local ent = NetworkGetEntityFromNetworkId(netId)
      if ent and DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    active[plate] = nil
    return { ok=true }
  else
    return { ok=false, reason='update_fail' }
  end
end)

lib.callback.register('esx_garage:takeOutVehicle', function(source, plate)
  local id = getIdentifier(source); if not id then return { ok=false, reason='noid' } end
  plate = string.upper(plate or ''); if not isPlateValid(plate) then return { ok=false, reason='plate' } end

  local row = MySQL.single.await('SELECT stored, impounded, vehicle FROM owned_vehicles WHERE owner=? AND plate=?', { id, plate })
  if not row then return { ok=false, reason='notfound' } end
  if row.impounded == 1 then return { ok=false, reason='impounded' } end
  if row.stored ~= 1 then return { ok=false, reason='already_out' } end

  local ok = MySQL.update.await('UPDATE owned_vehicles SET stored=0 WHERE owner=? AND plate=? AND stored=1', { id, plate })
  if ok ~= 1 then return { ok=false, reason='race' } end

  local props = json.decode(row.vehicle or '{}') or {}
  return { ok=true, props=props }
end)

-- ===== Server-side spawn & register
lib.callback.register('esx_garage:spawnOwnedVehicle', function(source, data)
  local id = getIdentifier(source); if not id then return { ok=false, reason='noid' } end
  local plate = string.upper(data.plate or ''); if not isPlateValid(plate) then return { ok=false, reason='plate' } end
  local model = data.model or 'adder'
  local x,y,z,w = data.pos.x, data.pos.y, data.pos.z, data.pos.w

  lib.requestModel(model) -- server-safe
  local veh = CreateVehicle(joaat(model), x, y, z, w or 0.0, true, true)
  if not veh or veh == 0 then return { ok=false, reason='create_fail' } end

  SetEntityAsMissionEntity(veh, true, true)
  SetVehicleOnGroundProperly(veh)
  SetVehicleNumberPlateText(veh, plate)
  local netId = NetworkGetNetworkIdFromEntity(veh)
  if not netId then DeleteEntity(veh); return { ok=false, reason='net_fail' } end

  active[plate] = { netId = netId, owner = id, last = vec3(x, y, z), ts = GetGameTimer() }
  return { ok=true, netId=netId }
end)

-- ===== Impound: fixed price
lib.callback.register('esx_garage:payRelease', function(source, plate)
  local xPlayer = ESX.GetPlayerFromId(source); if not xPlayer then return { ok=false, reason='noid' } end
  plate = string.upper(plate or ''); if not isPlateValid(plate) then return { ok=false, reason='plate' } end

  local row = MySQL.single.await('SELECT impounded FROM owned_vehicles WHERE owner=? AND plate=?', { xPlayer.getIdentifier(), plate })
  if not row or row.impounded ~= 1 then return { ok=false, reason='not_impounded' } end

  local fee = clamp(tonumber(Config.ImpoundPrice or 0), 0, 10000000)
  local account = Config.PayAccount or 'bank'
  if account == 'money' then
    if xPlayer.getMoney() < fee then return { ok=false, reason='notenough' } end
    xPlayer.removeMoney(fee)
  else
    if xPlayer.getAccount(account).money < fee then return { ok=false, reason='notenough' } end
    xPlayer.removeAccountMoney(account, fee)
  end
  MySQL.update.await('UPDATE owned_vehicles SET impounded=0, stored=1 WHERE owner=? AND plate=?', { xPlayer.getIdentifier(), plate })
  return { ok=true }
end)

-- Auto-impound เมื่อหาย/พัง
RegisterNetEvent('esx_garage:autoImpound', function(plate)
  plate = string.upper(plate or '')
  if not isPlateValid(plate) then return end
  MySQL.update.await('UPDATE owned_vehicles SET impounded=1, stored=1 WHERE plate=?', { plate })
  active[plate] = nil
end)
