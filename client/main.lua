local ESX = exports['es_extended']:getSharedObject()

local function isPlateValid(p) return p and p:match('^%u%u%u %d%d%d$') ~= nil end
local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end
local function pct(h) if not h then return nil end return clamp(math.floor((h/1000.0)*100 + 0.5), 0, 100) end
local function fmtStatus(vj)
  local e = pct(vj and vj.engineHealth); local b = pct(vj and vj.bodyHealth)
  local f = vj and vj.fuelLevel and clamp(math.floor(vj.fuelLevel + 0.5), 0, 100) or nil
  return ('HP %s | Body %s | Fuel %s'):format(e and (e..'%') or '-', b and (b..'%') or '-', f and (f..'%') or '-')
end

-- ===== Zones/points
local points = {}
CreateThread(function()
  for _, g in ipairs(Config.Garages) do
    local p = lib.points.new({ coords = g.coord, distance = 10.0 })
    function p:nearby()
      if self.currentDistance < 2.2 then
        lib.showTextUI('[E] เปิด '..g.label)
        if IsControlJustReleased(0, 38) then
          if g.type == 'impound' then OpenImpoundMenu(g) else OpenGarageMenu(g) end
        end
      else lib.hideTextUI() end
    end
    points[#points+1] = p
  end
end)

-- ===== Helpers: event-driven position updates
local function startPositionReporter(plate, veh, netId)
  local lastSend = GetGameTimer()
  local lastPos = GetEntityCoords(veh)
  CreateThread(function()
    while DoesEntityExist(veh) do
      Wait(1000) -- tick เบามาก
      local now = GetGameTimer()
      local pos = GetEntityCoords(veh)
      local dist = #(pos - lastPos)
      if dist > 75.0 or (now - lastSend) > 15000 then
        TriggerServerEvent('esx_garage:updateVehiclePos', plate, pos.x, pos.y, pos.z, netId)
        lastSend = now; lastPos = pos
      end
      if IsEntityDead(veh) then
        TriggerServerEvent('esx_garage:autoImpound', plate)
        TriggerServerEvent('esx_garage:clearActive', plate)
        break
      end
    end
    if not DoesEntityExist(veh) then
      TriggerServerEvent('esx_garage:autoImpound', plate)
      TriggerServerEvent('esx_garage:clearActive', plate)
    end
  end)
end

-- ===== Menus
function OpenGarageMenu(garage)
  local vehicles = lib.callback.await('esx_garage:getPlayerVehicles', false)
  local opts = {}

  if IsPedInAnyVehicle(PlayerPedId(), false) then
    opts[#opts+1] = {
      title = 'เก็บรถคันนี้',
      icon = 'box',
      onSelect = function()
        local veh = GetVehiclePedIsIn(PlayerPedId(), false); if veh == 0 then return end
        local plate = string.upper(GetVehicleNumberPlateText(veh) or '')
        if not isPlateValid(plate) then lib.notify({ title='ป้ายทะเบียนผิดรูปแบบ', type='error' }); return end
        local status = { engine=GetVehicleEngineHealth(veh) or 1000.0, body=GetVehicleBodyHealth(veh) or 1000.0, fuel=GetVehicleFuelLevel(veh) or 50.0 }
        local netId = NetworkGetNetworkIdFromEntity(veh)
        local ok = lib.callback.await('esx_garage:storeVehicle', false, plate, status, netId)
        if ok and ok.ok then
          -- ฝั่งเซิร์ฟเวอร์จะ DeleteEntity ให้แล้ว
          lib.notify({ title=('เก็บ %s แล้ว'):format(plate), type='success' })
        else
          lib.notify({ title='เก็บไม่ได้', description=ok and ok.reason or '', type='error' })
        end
      end
    }
  end

  for i=1, #vehicles do
    local v = vehicles[i]
    local name = (v.vehicle and v.vehicle.model) or v.plate
    local tag = (v.state == 'in_garage' and 'IN') or (v.state == 'out_garage' and 'OUT') or 'IMP'
    opts[#opts+1] = {
      title = ('%s [%s]'):format(v.plate, tag),
      description = ('%s | %s'):format(name, fmtStatus(v.vehicle)),
      arrow = true,
      onSelect = function()
        if v.state == 'in_impound' then
          lib.notify({ title='รถถูกยึด', description='ไปที่ Impound', type='error' }); return
        end
        if v.state == 'out_garage' then
          local res = lib.callback.await('esx_garage:getVehicleCoords', false, v.plate)
          if res and res.ok then SetNewWaypoint(res.coords.x + 0.0, res.coords.y + 0.0); lib.notify({ title='ตั้ง waypoint แล้ว', type='inform' })
          else lib.notify({ title='ไม่พบพิกัด', description=res and res.reason or '', type='error' }) end
          return
        end

        -- choose free spot
        local free
        for _, s in ipairs(garage.spawn) do
          if not IsAnyVehicleNearPoint(s.x, s.y, s.z, Config.SpawnRadiusCheck) then free = s break end
        end
        if not free then lib.notify({ title='จุดสปอว์นเต็ม', type='error' }); return end

        local grant = lib.callback.await('esx_garage:takeOutVehicle', false, v.plate)
        if not grant or not grant.ok then lib.notify({ title='สปอว์นล้มเหลว', description=grant and grant.reason or '', type='error' }); return end

        -- สร้างรถ “โดยเซิร์ฟเวอร์”
        local model = (grant.props and grant.props.model) or (v.vehicle and v.vehicle.model) or 'adder'
        local spawnRes = lib.callback.await('esx_garage:spawnOwnedVehicle', false, { plate = v.plate, model = model, pos = { x = free.x, y = free.y, z = free.z, w = free.w } })
        if not spawnRes or not spawnRes.ok then lib.notify({ title='สร้างรถล้มเหลว', description=spawnRes and spawnRes.reason or '', type='error' }); return end

        -- apply saved props client-side
        local veh = NetworkGetEntityFromNetworkId(spawnRes.netId)
        if veh and veh ~= 0 then
          local pr = grant.props or v.vehicle
          if pr then
            if pr.engineHealth then SetVehicleEngineHealth(veh, pr.engineHealth) end
            if pr.bodyHealth then SetVehicleBodyHealth(veh, pr.bodyHealth) end
            if pr.fuelLevel then SetVehicleFuelLevel(veh, pr.fuelLevel) end
          end
          Entity(veh).state.isGarageVehicle = true
          lib.notify({ title=('สปอว์น %s สำเร็จ'):format(v.plate), type='success' })
          startPositionReporter(v.plate, veh, spawnRes.netId)
        else
          lib.notify({ title='spawn netId ไม่ถูกต้อง', type='error' })
        end
      end
    }
  end

  lib.registerContext({ id='esx_garage_menu', title=garage.label, options=opts })
  lib.showContext('esx_garage_menu')
end

function OpenImpoundMenu(garage)
  local vehicles = lib.callback.await('esx_garage:getImpoundedVehicles', false)
  local opts = {}
  for i=1, #vehicles do
    local v = vehicles[i]
    local model = (v.vehicle and v.vehicle.model) or 'adder'
    opts[#opts+1] = {
      title = ('%s | ค่าปลด %d'):format(v.plate, Config.ImpoundPrice),
      description = ('%s | %s'):format(model, fmtStatus(v.vehicle)),
      arrow = true,
      onSelect = function()
        local free
        for _, s in ipairs(garage.spawn) do
          if not IsAnyVehicleNearPoint(s.x, s.y, s.z, Config.SpawnRadiusCheck) then free = s break end
        end
        if not free then lib.notify({ title='จุดสปอว์นเต็ม', type='error' }); return end

        local ok = lib.callback.await('esx_garage:payRelease', false, v.plate)
        if not ok or not ok.ok then lib.notify({ title='ชำระล้มเหลว', description=ok and ok.reason or '', type='error' }); return end

        local spawnRes = lib.callback.await('esx_garage:spawnOwnedVehicle', false, { plate = v.plate, model = model, pos = { x = free.x, y = free.y, z = free.z, w = free.w } })
        if not spawnRes or not spawnRes.ok then lib.notify({ title='สร้างรถล้มเหลว', description=spawnRes and spawnRes.reason or '', type='error' }); return end

        local veh = NetworkGetEntityFromNetworkId(spawnRes.netId)
        if veh and veh ~= 0 then
          if v.vehicle then
            if v.vehicle.engineHealth then SetVehicleEngineHealth(veh, v.vehicle.engineHealth) end
            if v.vehicle.bodyHealth then SetVehicleBodyHealth(veh, v.vehicle.bodyHealth) end
            if v.vehicle.fuelLevel then SetVehicleFuelLevel(veh, v.vehicle.fuelLevel) end
          end
          Entity(veh).state.isGarageVehicle = true
          lib.notify({ title=('รับรถ %s สำเร็จ'):format(v.plate), type='success' })
          startPositionReporter(v.plate, veh, spawnRes.netId)
        else
          lib.notify({ title='spawn netId ไม่ถูกต้อง', type='error' })
        end
      end
    }
  end
  lib.registerContext({ id='esx_garage_impound', title=garage.label, options=opts })
  lib.showContext('esx_garage_impound')
end

-- ===== Contract item handler (คงไฟล์ server/contract.lua เดิม)
RegisterNetEvent('esx_garage:useContract', function()
  local ped = PlayerPedId()
  local veh = GetVehiclePedIsIn(ped, false)
  if veh == 0 then lib.notify({ title='ต้องยืนใกล้รถของคุณ', type='error' }); return end
  local plate = string.upper(GetVehicleNumberPlateText(veh) or '')
  if not isPlateValid(plate) then lib.notify({ title='ป้ายทะเบียนผิดรูปแบบ', type='error' }); return end
  local input = lib.inputDialog('โอนกรรมสิทธิ์รถ', {
    { type='number', label='Server ID ผู้รับ', required=true, min=1 },
    { type='number', label='ราคา', required=true, min=0 }
  }); if not input then return end
  local target, price = tonumber(input[1]), tonumber(input[2])
  local agree = lib.alertDialog({ header='ยืนยันสัญญา', content=('ขาย %s ให้ %s ราคา %d ?'):format(plate, target, price), centered=true, cancel=true })
  if agree ~= 'confirm' then return end
  local res = lib.callback.await('esx_garage:transferVehicle', false, { plate=plate, target=target, price=price })
  if res and res.ok then lib.notify({ title='โอนสำเร็จ', type='success' }) else lib.notify({ title='โอนไม่สำเร็จ', description=res and res.reason or '', type='error' }) end
end)
