local ESX = exports['es_extended']:getSharedObject()

local usingTarget = GetResourceState('ox_target') == 'started'
local lastSpawn = nil
local activeCam = nil
local previewVeh = nil

local function isPlateValid(plate)
    return plate and plate:match('^%u%u%u %d%d%d$') ~= nil
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function pctFromHealth(h) -- GTA health 0..1000
    if not h then return nil end
    return clamp(math.floor((h / 1000.0) * 100 + 0.5), 0, 100)
end

local function formatStatusStr(vj)
    local eng = pctFromHealth(vj and vj.engineHealth)
    local bod = pctFromHealth(vj and vj.bodyHealth)
    local fuel = vj and vj.fuelLevel and clamp(math.floor(vj.fuelLevel + 0.5), 0, 100) or nil
    local sEng = eng and (eng .. '%') or '-'
    local sBod = bod and (bod .. '%') or '-'
    local sFuel = fuel and (fuel .. '%') or '-'
    return ('HP %s | Body %s | Fuel %s'):format(sEng, sBod, sFuel), eng, bod, fuel
end

local function destroyPreview()
    if previewVeh and DoesEntityExist(previewVeh) then
        DeleteEntity(previewVeh)
    end
    previewVeh = nil
    if activeCam then
        RenderScriptCams(false, true, 300, true, true)
        DestroyCam(activeCam, false)
        activeCam = nil
    end
end

local function showPreview(garage, model, spot, vj)
    destroyPreview()
    if not model or model == '' then model = 'adder' end
    lib.requestModel(model)
    previewVeh = CreateVehicle(joaat(model), spot.x, spot.y, spot.z, spot.w, false, true)
    SetEntityCollision(previewVeh, false, false)
    FreezeEntityPosition(previewVeh, true)
    SetVehicleOnGroundProperly(previewVeh)
    -- apply visualized status if present
    if vj then
        if vj.engineHealth then SetVehicleEngineHealth(previewVeh, vj.engineHealth) end
        if vj.bodyHealth then SetVehicleBodyHealth(previewVeh, vj.bodyHealth) end
        if vj.fuelLevel then SetVehicleFuelLevel(previewVeh, vj.fuelLevel) end
    end
    -- camera
    local offset = garage.previewCamOffset or vec3(3.0, 3.0, 1.5)
    activeCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    local camPos = GetOffsetFromEntityInWorldCoords(previewVeh, offset.x, offset.y, offset.z)
    SetCamCoord(activeCam, camPos.x, camPos.y, camPos.z)
    PointCamAtEntity(activeCam, previewVeh, 0.0, 0.0, 0.0, true)
    SetCamFov(activeCam, 45.0)
    RenderScriptCams(true, true, 300, true, true)
end

local function findFreeSpot(spots)
    for i = 1, #spots do
        local s = spots[i]
        if not IsAnyVehicleNearPoint(s.x, s.y, s.z, 3.5) then
            return s
        end
    end
    return nil
end

local function openImpoundMenu(garage)
    local vehicles = lib.callback.await('esx_garage:getImpoundVehicles', false)
    local options = {}
    for i = 1, #vehicles do
        local v = vehicles[i]
        local model = (v.vehicle and v.vehicle.model) or 'adder'
        local statusStr = formatStatusStr(v.vehicle)
        options[#options+1] = {
            title = ('%s | ค่าปลด %d'):format(v.plate, v.impound_fee or 0),
            description = ('%s | %s'):format(model, statusStr),
            arrow = true,
            onSelect = function()
                local spot = findFreeSpot(garage.spawn)
                if not spot then
                    lib.notify({ title = 'ไม่มีที่ว่าง', type = 'error' })
                    return
                end
                showPreview(garage, model, spot, v.vehicle)
                local ok = lib.alertDialog({
                    header = ('ปลดรถ %s'):format(v.plate),
                    content = ('ยืนยันชำระค่าปลด %d ?'):format(v.impound_fee or 0),
                    centered = true,
                    cancel = true,
                    labels = { confirm = 'ชำระและสปอว์น' }
                })
                if ok ~= 'confirm' then
                    destroyPreview()
                    return
                end
                local paid = lib.callback.await('esx_garage:payRelease', false, v.plate)
                if not paid or not paid.ok then
                    destroyPreview()
                    lib.notify({ title = 'ชำระเงินล้มเหลว', description = paid and paid.reason or '', type = 'error' })
                    return
                end
                lib.requestModel(model)
                local veh = CreateVehicle(joaat(model), spot.x, spot.y, spot.z, spot.w, true, false)
                SetEntityAsMissionEntity(veh, true, true)
                SetVehicleOnGroundProperly(veh)
                SetVehicleNumberPlateText(veh, v.plate)
                if v.vehicle then
                    if v.vehicle.engineHealth then SetVehicleEngineHealth(veh, v.vehicle.engineHealth) end
                    if v.vehicle.bodyHealth then SetVehicleBodyHealth(veh, v.vehicle.bodyHealth) end
                    if v.vehicle.fuelLevel then SetVehicleFuelLevel(veh, v.vehicle.fuelLevel) end
                end
                Entity(veh).state.isGarageVehicle = true
                lastSpawn = veh
                destroyPreview()
                lib.notify({ title = ('รับรถ %s สำเร็จ'):format(v.plate), type = 'success' })
            end
        }
    end
    lib.registerContext({ id = 'esx_garage_impound', title = garage.label, options = options })
    lib.showContext('esx_garage_impound')
end

local function openGarageMenu(garage)
    if garage.type == 'impound' then
        openImpoundMenu(garage); return
    end

    local vehicles = lib.callback.await('esx_garage:getPlayerVehicles', false, garage.id)
    local options = {}

    -- เก็บรถคันที่นั่งอยู่ พร้อม snapshot สถานะ
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        options[#options+1] = {
            title = 'เก็บรถคันนี้',
            icon = 'box',
            onSelect = function()
                local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                if veh == 0 then return end
                local plate = string.upper(GetVehicleNumberPlateText(veh) or '')
                if not isPlateValid(plate) then
                    lib.notify({ title = 'ป้ายทะเบียนไม่ตรงรูปแบบ', type = 'error' })
                    return
                end
                local status = {
                    engine = GetVehicleEngineHealth(veh) or 1000.0,
                    body = GetVehicleBodyHealth(veh) or 1000.0,
                    fuel = GetVehicleFuelLevel(veh) or 50.0
                }
                local ok = lib.callback.await('esx_garage:storeVehicle', false, plate, garage.id, status)
                if ok and ok.ok then
                    DeleteEntity(veh)
                    lib.notify({ title = ('เก็บรถ %s แล้ว'):format(plate), type = 'success' })
                else
                    lib.notify({ title = 'เก็บรถไม่ได้', description = ok and ok.reason or '', type = 'error' })
                end
            end
        }
    end

    for i = 1, #vehicles do
        local v = vehicles[i]
        local name = (v.vehicle and v.vehicle.model) or v.plate
        local statusStr = formatStatusStr(v.vehicle)
        local status = (v.stored == 1 and 'IN' or 'OUT')
        options[#options+1] = {
            title = ('%s [%s]'):format(v.plate, status),
            description = ('%s | %s'):format(name, statusStr),
            arrow = true,
            onSelect = function()
                if v.stored ~= 1 then
                    lib.notify({ title = 'รถอยู่นอกโรง', type = 'error' })
                    return
                end
                local spot = findFreeSpot(garage.spawn)
                if not spot then
                    lib.notify({ title = 'ไม่มีที่ว่าง', type = 'error' })
                    return
                end
                showPreview(garage, (v.vehicle and v.vehicle.model) or 'adder', spot, v.vehicle)
                local ok = lib.alertDialog({
                    header = ('สปอว์น %s'):format(v.plate),
                    content = 'ยืนยันสปอว์นที่จุดที่ว่าง',
                    centered = true,
                    cancel = true
                })
                if ok ~= 'confirm' then
                    destroyPreview()
                    return
                end

                if not isPlateValid(v.plate) then
                    destroyPreview()
                    lib.notify({ title = 'ป้ายทะเบียนไม่ตรงรูปแบบ', type = 'error' })
                    return
                end

                local grant = lib.callback.await('esx_garage:requestSpawn', false, v.plate, garage.id)
                if not grant or not grant.ok then
                    destroyPreview()
                    lib.notify({ title = 'สปอว์นล้มเหลว', description = grant and grant.reason or '', type = 'error' })
                    return
                end

                local model = (v.vehicle and v.vehicle.model) or 'adder'
                lib.requestModel(model)
                local veh = CreateVehicle(joaat(model), spot.x, spot.y, spot.z, spot.w, true, false)
                SetEntityAsMissionEntity(veh, true, true)
                SetVehicleOnGroundProperly(veh)
                SetVehicleNumberPlateText(veh, v.plate)
                if v.vehicle then
                    if v.vehicle.engineHealth then SetVehicleEngineHealth(veh, v.vehicle.engineHealth) end
                    if v.vehicle.bodyHealth then SetVehicleBodyHealth(veh, v.vehicle.bodyHealth) end
                    if v.vehicle.fuelLevel then SetVehicleFuelLevel(veh, v.vehicle.fuelLevel) end
                end
                Entity(veh).state.isGarageVehicle = true
                lastSpawn = veh
                destroyPreview()
                lib.notify({ title = ('สปอว์น %s สำเร็จ'):format(v.plate), type = 'success' })
            end
        }
    end

    lib.registerContext({ id = 'esx_garage_menu', title = garage.label, options = options })
    lib.showContext('esx_garage_menu')
end

-- โซนเข้าใช้งาน: รองรับทั้ง target และ E
CreateThread(function()
    for _, g in ipairs(Config.Garages) do
        if usingTarget and exports.ox_target then
            exports.ox_target:addSphereZone({
                coords = g.coord,
                radius = 2.0,
                debug = false,
                options = {
                    {
                        name = ('garage:%s'):format(g.id),
                        label = ('เปิด %s'):format(g.label),
                        icon = 'car',
                        onSelect = function() openGarageMenu(g) end
                    }
                }
            })
        else
            lib.zones.sphere({
                coords = g.coord, radius = 2.0, debug = false,
                onEnter = function() lib.showTextUI('[E] เปิด ' .. g.label) end,
                onExit  = function() lib.hideTextUI() end
            })
        end
    end
end)

RegisterKeyMapping('garage_open', 'เปิดเมนู Garage', 'keyboard', 'E')
RegisterCommand('garage_open', function()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    for _, g in ipairs(Config.Garages) do
        if #(pos - g.coord) < 2.2 then
            openGarageMenu(g)
            break
        end
    end
end, false)

-- เฝ้ารถที่สปอว์น ถ้าหาย/พัง → auto impound
CreateThread(function()
    while true do
        Wait(3000)
        if lastSpawn and DoesEntityExist(lastSpawn) then
            if IsEntityDead(lastSpawn) then
                local plate = string.upper(GetVehicleNumberPlateText(lastSpawn) or '')
                if isPlateValid(plate) then
                    TriggerServerEvent('esx_garage:autoImpound', plate)
                end
                lastSpawn = nil
            end
        elseif lastSpawn and not DoesEntityExist(lastSpawn) then
            local plate = string.upper(GetVehicleNumberPlateText(lastSpawn) or '')
            if isPlateValid(plate) then
                TriggerServerEvent('esx_garage:autoImpound', plate)
            end
            lastSpawn = nil
        end
    end
end)
