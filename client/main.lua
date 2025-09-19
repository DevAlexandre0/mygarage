local cache = {}
local currentGarage = nil

local function openGarageMenu(garage)
  currentGarage = garage
  local vehicles = lib.callback.await('esx_garage:getPlayerVehicles', false, garage.id)
  local options = {}

  for i=1, #vehicles do
    local v = vehicles[i]
    local name = v.vehicle and v.vehicle.model or v.plate
    local status = v.impounded == 1 and 'IMP' or (v.stored == 1 and 'IN' or 'OUT')
    options[#options+1] = {
      title = ('%s [%s]'):format(v.plate, status),
      description = name,
      arrow = true,
      onSelect = function()
        if v.impounded == 1 then
          lib.notify({ title = 'รถถูกยึด', description = 'ไปที่ Impound เพื่อไถ่ถอน', type = 'error' })
          return
        end
        if v.stored ~= 1 then
          lib.notify({ title = 'รถอยู่นอกโรง', type = 'error' })
          return
        end
        local ok = lib.callback.await('esx_garage:requestSpawn', false, v.plate, garage.id)
        if not ok or not ok.ok then
          lib.notify({ title = 'สปอว์นล้มเหลว', description = ok and ok.reason or '', type = 'error' })
          return
        end
        -- จุดสปอว์นแรกที่ว่าง
        local spot = garage.spawn[1]
        local model = v.vehicle and v.vehicle.model or 'adder'
        lib.requestModel(model)
        local veh = CreateVehicle(joaat(model), spot.x, spot.y, spot.z, spot.w, true, false)
        SetVehicleOnGroundProperly(veh)
        SetVehicleNumberPlateText(veh, v.plate)
        Entity(veh).state.isGarageVehicle = true -- state bag
        lib.notify({ title = ('สปอว์น %s'):format(v.plate), type = 'success' })
      end
    }
  end

  lib.registerContext({ id = 'esx_garage_menu', title = garage.label, options = options })
  lib.showContext('esx_garage_menu')
end

-- ตัวอย่างจุด target แบบง่าย
CreateThread(function()
  if not lib then return end
  for _, g in ipairs(Config.Garages) do
    local zone = lib.zones.sphere({
      coords = g.coord, radius = 2.0, debug = false,
      onEnter = function() lib.showTextUI('[E] เปิด Garage') end,
      onExit  = function() lib.hideTextUI() end
    })
    cache[g.id] = zone
  end
end)

RegisterCommand('garage', function()
  -- ใช้จุดแรกเป็นตัวอย่าง
  local g = Config.Garages[1]
  if g then openGarageMenu(g) end
end)
