local currentGarage = nil

local function isCarModel(model)
  local cls = GetVehicleClassFromName(model) -- client-only
  return not Config.ForbidVehicleClasses[cls]
end

local function openGarageMenu(garage)
  currentGarage = garage
  local vehicles = lib.callback.await('esx_garage:getPlayerVehicles', false, garage.id)

  local options = {}

  -- แท็บ: รถของฉัน
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
          lib.notify({ title = 'รถถูกยึด', description = 'เลือกเมนู Impound เพื่อไถ่ถอน', type = 'error' })
          return
        end
        if v.stored ~= 1 then
          lib.notify({ title = 'รถอยู่นอกโรง', type = 'error' })
          return
        end

        local model = (v.vehicle and v.vehicle.model) or 'adder'
        if not isCarModel(joaat(model)) then
          lib.notify({ title = 'อนุญาตเฉพาะรถยนต์', type = 'error' })
          return
        end

        local spot = garage.spawn[1]
        local ok = lib.callback.await('esx_garage:spawnFromServer', false, {
          plate = v.plate,
          model = model,
          garageId = garage.id,
          coord = { x = spot.x, y = spot.y, z = spot.z, w = spot.w }
        })
        if not ok or not ok.ok then
          lib.notify({ title = 'สปอว์นล้มเหลว', description = ok and ok.reason or '', type = 'error' })
        else
          lib.notify({ title = ('สปอว์น %s'):format(v.plate), type = 'success' })
        end
      end
    }
  end

  -- แท็บ: Impound
  options[#options+1] = {
    title = 'Impound',
    description = 'รถที่ถูกยึด / ไถ่ถอน',
    onSelect = function()
      local list = lib.callback.await('esx_garage:getImpounded', false)
      if #list == 0 then lib.notify({ title = 'ไม่มีรถถูกยึด' }); return end
      local opts = {}
      for i=1, #list do
        local r = list[i]
        opts[#opts+1] = {
          title = ('%s | ค่าธรรมเนียม %d'):format(r.plate, r.impound_fee or 0),
          onSelect = function()
            local ok = lib.callback.await('esx_garage:releaseImpound', false, r.plate, currentGarage and currentGarage.id)
            if ok and ok.ok then
              lib.notify({ title = 'ไถ่ถอนสำเร็จ', type = 'success' })
            else
              lib.notify({ title = 'ไถ่ถอนไม่สำเร็จ', description = ok and ok.reason or '', type = 'error' })
            end
          end
        }
      end
      lib.registerContext({ id = 'esx_garage_impound', title = 'Impound', options = opts })
      lib.showContext('esx_garage_impound')
    end
  }

  lib.registerContext({ id = 'esx_garage_menu', title = garage.label, options = options })
  lib.showContext('esx_garage_menu')
end

-- จุดตัวอย่าง + คีย์เรียกเมนู
CreateThread(function()
  for _, g in ipairs(Config.Garages) do
    local zone = lib.zones.sphere({
      coords = g.coord, radius = 2.0, debug = false,
      onEnter = function() lib.showTextUI('[E] เปิด Garage') end,
      onExit  = function() lib.hideTextUI() end
    })
    zone:onKey('E', function() openGarageMenu(g) end)
  end
end)

-- Global vehicle target: trunk/glovebox via ox_inventory
CreateThread(function()
  if not Config.UseOxInventory then return end
  exports.ox_target:addGlobalVehicle({
    {
      name = 'esx_garage_trunk',
      icon = 'fa-solid fa-car',
      label = 'เปิดกระโปรงท้าย',
      canInteract = function(entity, distance, coords, name, bone)
        local plate = GetVehicleNumberPlateText(entity)
        return plate and plate:match(Config.PlatePattern) ~= nil
      end,
      onSelect = function(data)
        local veh = data.entity
        local plate = GetVehicleNumberPlateText(veh)
        exports.ox_inventory:openInventory('trunk', plate)
      end
    },
    {
      name = 'esx_garage_glove',
      icon = 'fa-solid fa-hand',
      label = 'เปิดเก๊ะหน้า',
      canInteract = function(entity)
        local plate = GetVehicleNumberPlateText(entity)
        return plate and plate:match(Config.PlatePattern) ~= nil
      end,
      onSelect = function(data)
        local plate = GetVehicleNumberPlateText(data.entity)
        exports.ox_inventory:openInventory('glovebox', plate)
      end
    }
  })
end)

-- คำสั่งทดสอบเมนู
RegisterCommand('garage', function()
  local g = Config.Garages[1]
  if g then openGarageMenu(g) end
end)
