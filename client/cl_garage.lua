local ESX = exports['es_extended']:getSharedObject()
local lastOpen = 0
local currentGarage = nil
local points = {}

-- สร้าง blip และจุดโต้ตอบ
CreateThread(function()
    for _, g in ipairs(Config.Garages) do
        -- blip
        if g.blip then
            local blip = AddBlipForCoord(g.enter.x, g.enter.y, g.enter.z)
            SetBlipSprite(blip, g.blip.sprite or 357)
            SetBlipScale(blip, g.blip.scale or 0.7)
            SetBlipColour(blip, g.blip.color or 3)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(g.label or 'Garage')
            EndTextCommandSetBlipName(blip)
        end

        -- ox_lib point
        local p = lib.points.new(g.enter, g.radius or 2.0, { id = g.id })
        function p:onEnter()
            lib.showTextUI('[E] Open Garage')
        end
        function p:onExit()
            lib.hideTextUI()
        end
        function p:nearby()
            if self.currentDistance < 1.5 and IsControlJustPressed(0, 38) then -- E
                currentGarage = g
                openGarage()
            end
        end
        points[g.id] = p
    end
end)

function openGarage()
    if GetGameTimer() - lastOpen < 500 then return end
    lastOpen = GetGameTimer()

    local vehicles = lib.callback.await('esx_nfs_garage:list', false)
    SendNUIMessage({ action = 'open', vehicles = vehicles })
    SetNuiFocus(true, true)
end

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb(1)
end)

RegisterNUICallback('switch', function(data, cb)
    if not currentGarage then cb(0) return end
    local t = GetGameTimer()
    if t - (cache._lastSwitch or 0) < Config.SwitchCooldown then
        cb(0) return
    end
    cache._lastSwitch = t
    TriggerServerEvent('esx_nfs_garage:switch', {
        plate = data.plate,
        garageId = currentGarage.id
    })
    cb(1)
end)

-- ลบรถเดิมและสปอนรถใหม่
RegisterNetEvent('esx_nfs_garage:spawn', function(data)
    local playerPed = PlayerPedId()

    -- ลบรถที่กำลังขับอยู่ถ้ามีและเป็นของผู้เล่น
    if IsPedInAnyVehicle(playerPed, false) then
        local veh = GetVehiclePedIsIn(playerPed, false)
        if GetPedInVehicleSeat(veh, -1) == playerPed then
            SetEntityAsMissionEntity(veh, true, true)
            DeleteVehicle(veh)
        end
    end

    local spawn = currentGarage and currentGarage.spawn or GetEntityCoords(playerPed)
    lib.requestModel(data.props.model or data.props.modelHash, 3000)

    local veh = CreateVehicle(data.props.model or data.props.modelHash, spawn.x, spawn.y, spawn.z, spawn.w or 0.0, true, false)
    SetVehicleOnGroundProperly(veh)
    SetVehicleNumberPlateText(veh, data.plate or 'ESXGRG')

    -- ใช้ ESX API ตั้งค่า props
    if ESX and ESX.Game and ESX.Game.SetVehicleProperties then
        ESX.Game.SetVehicleProperties(veh, data.props or {})
    end

    SetPedIntoVehicle(playerPed, veh, -1)
    SetVehicleEngineOn(veh, true, true, false)

    if Config.Debug then
        print(('[GARAGE] spawned %s'):format(data.plate))
    end
end)
