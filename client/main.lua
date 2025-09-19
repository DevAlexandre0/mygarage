local GARAGES = {}
local currentGarage, previewVeh, previewCam = nil, nil, nil

-- sync garages from server + config
RegisterNetEvent('esx_garage:syncGarages', function(list) GARAGES = list end)
CreateThread(function() TriggerServerEvent('esx_garage:requestGarages') end)

local function isCarModel(modelHash)
  local cls = GetVehicleClassFromName(modelHash)
  return not Config.ForbidVehicleClasses[cls]
end

local function findFreeSpot(garage)
  for i=1, #garage.spawn do
    local s = garage.spawn[i]
    local veh = GetClosestVehicle(s.x, s.y, s.z, Config.SpawnDistanceCheck, 0, 70)
    if not DoesEntityExist(veh) then return s end
  end
  return nil
end

local function clearPreview()
  if DoesEntityExist(previewVeh) then DeleteEntity(previewVeh) end
  previewVeh = nil
  if previewCam then RenderScriptCams(false, false, 0, true, true); DestroyCam(previewCam, false) end
  previewCam = nil
end

local function showPreview(garage, model)
  clearPreview()
  local spot = garage.spawn[1] or garage.spawn
  if not spot then return end
  lib.requestModel(model)
  previewVeh = CreateVehicle(joaat(model), spot.x, spot.y, spot.z + 0.05, spot.w, false, false)
  SetEntityCollision(previewVeh, false, false)
  SetEntityAlpha(previewVeh, 180, false)
  FreezeEntityPosition(previewVeh, true)

  local camPos = vec3(spot.x - 5.0, spot.y - 5.0, spot.z + 2.0)
  previewCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
  SetCamCoord(previewCam, camPos.x, camPos.y, camPos.z)
  PointCamAtEntity(previewCam, previewVeh)
  RenderScriptCams(true, false, 0, true, true)
end

local function openVehicleSubmenu(garage, v)
  local model = (v.vehicle and v.vehicle.model) or 'adder'
  lib.registerContext({
    id = 'esx_garage_vehicle_actions',
    title = ('%s'):format(v.plate),
    options = {
      {
        title = 'Preview',
        onSelect = function() showPreview(garage, model) end
      },
      {
        title = 'Spawn',
        onSelect = function()
          clearPreview()
          if v.impounded == 1 then lib.notify({title='ถูกยึด', type='error'}); return end
          if v.stored ~= 1 then lib.notify({title='อยู่นอกโรง', type='error'}); return end
          if not isCarModel(joaat(model)) then lib.notify({title='เฉพาะรถยนต์', type='error'}); return end
          local free = findFreeSpot(garage)
          if not free then lib.notify({title='จุดว่างไม่พอ', type='error'}); return end
          local ok = lib.callback.await('esx_garage:spawnFromServer', false, {
            plate=v.plate, model=model, garageId=garage.id, coord={x=free.x,y=free.y,z=free.z,w=free.w}
          })
          if ok and ok.ok then lib.notify({title=('สปอว์น %s'):format(v.plate), type='success'})
          else lib.notify({title='สปอว์นล้มเหลว', description=ok and ok.reason or '', type='error'}) end
        end
      },
      {
        title = 'Transfer to this garage',
        description = 'ย้ายที่เก็บมายังที่นี่',
        onSelect = function()
          local ok = lib.callback.await('esx_garage:transferGarage', false, v.plate, garage.id)
          if ok and ok.ok then lib.notify({ title='ย้ายสำเร็จ', type='success' })
          else lib.notify({ title='ย้ายไม่สำเร็จ', description=ok and ok.reason or '', type='error' }) end
        end
      }
    }
  })
  lib.showContext('esx_garage_vehicle_actions')
end

local function openGarageMenu(garage)
  currentGarage = garage
  clearPreview()
  local vehicles = lib.callback.await('esx_garage:getPlayerVehicles', false, garage.id)
  local options = {}

  for i=1, #vehicles do
    local v = vehicles[i]
    local status = v.impounded == 1 and 'IMP' or (v.stored == 1 and 'IN' or 'OUT')
    local label = (v.vehicle and v.vehicle.model) or v.plate
    options[#options+1] = {
      title = ('%s [%s]'):format(v.plate, status),
      description = label,
      arrow = true,
      onSelect = function() openVehicleSubmenu(garage, v) end
    }
  end

  options[#options+1] = {
    title = 'Impound',
    description = 'รถที่ถูกยึด / ไถ่ถอน',
    onSelect = function()
      local list = lib.callback.await('esx_garage:getImpounded', false)
      if #list == 0 then lib.notify({ title='ไม่มีรถถูกยึด' }); return end
      local opts = {}
      for i=1, #list do
        local r = list[i]
        opts[#opts+1] = {
          title = ('%s | ค่าธรรมเนียม %d'):format(r.plate, r.impound_fee or 0),
          onSelect = function()
            local ok = lib.callback.await('esx_garage:releaseImpound', false, r.plate, currentGarage and currentGarage.id)
            if ok and ok.ok then lib.notify({ title='ไถ่ถอนสำเร็จ', type='success' })
            else lib.notify({ title='ไถ่ถอนไม่สำเร็จ', description=ok and ok.reason or '', type='error' }) end
          end
        }
      end
      lib.registerContext({ id='esx_garage_impound', title='Impound', options=opts })
      lib.showContext('esx_garage_impound')
    end
  }

  lib.registerContext({ id='esx_garage_menu', title=garage.label, options=options })
  lib.showContext('esx_garage_menu')
end

-- zones
CreateThread(function()
  while GARAGES == nil or next(GARAGES) == nil do Wait(500) end
  for _, g in ipairs(GARAGES) do
    local zone = lib.zones.sphere({
      coords=g.coord, radius=2.2, debug=false,
      onEnter=function() lib.showTextUI('[E] เปิด Garage') end,
      onExit=function() lib.hideTextUI(); clearPreview() end
    })
    zone:onKey('E', function() openGarageMenu(g) end)
  end
end)

-- ox_target: Trunk / Glovebox with permission check
CreateThread(function()
  if not Config.UseOxInventory then return end
  exports.ox_target:addGlobalVehicle({
    {
      name='esx_garage_trunk', icon='fa-solid fa-box-open', label='เปิดกระโปรงท้าย',
      canInteract=function(entity) return Utils.matchPlate(GetVehicleNumberPlateText(entity)) end,
      onSelect=function(data)
        local plate = GetVehicleNumberPlateText(data.entity)
        local ok = lib.callback.await('esx_garage:canOpenInventory', false, plate)
        if ok then exports.ox_inventory:openInventory('trunk', plate)
        else lib.notify({title='ไม่ได้รับอนุญาต', type='error'}) end
      end
    },
    {
      name='esx_garage_glove', icon='fa-solid fa-hand', label='เปิดเก๊ะหน้า',
      canInteract=function(entity) return Utils.matchPlate(GetVehicleNumberPlateText(entity)) end,
      onSelect=function(data)
        local plate = GetVehicleNumberPlateText(data.entity)
        local ok = lib.callback.await('esx_garage:canOpenInventory', false, plate)
        if ok then exports.ox_inventory:openInventory('glovebox', plate)
        else lib.notify({title='ไม่ได้รับอนุญาต', type='error'}) end
      end
    },
    {
      name='esx_garage_impound', icon='fa-solid fa-triangle-exclamation', label='ยึดรถ (Police)',
      onSelect=function(data)
        local plate = GetVehicleNumberPlateText(data.entity)
        local input = lib.inputDialog('Impound Vehicle', {
          {type='number', label='ค่าธรรมเนียม', default=Config.Impound.MinFee, min=Config.Impound.MinFee, max=Config.Impound.MaxFee}
        })
        if not input then return end
        TriggerServerEvent('esx_garage:policeImpound', plate, input[1] or Config.Impound.MinFee)
      end
    }
  })
end)

-- test command
RegisterCommand('garage', function()
  for _, g in ipairs(GARAGES) do if g.id == 'legion_public' then openGarageMenu(g) return end end
end)
