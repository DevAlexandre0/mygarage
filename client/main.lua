local ESX = exports['es_extended']:getSharedObject()

local usingTarget = GetResourceState('ox_target') == 'started'
local lastSpawn = nil
local activeCam = nil
local previewVeh = nil

local function isPlateValid(plate)
    -- รูปแบบ "AAA 111"
    return plate and plate:match('^%u%u%u %d%d%d$') ~= nil
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

local function showPreview(garage, model, spot)
    destroyPreview()
    if not model or model == '' then model = 'adder' end
    lib.requestModel(model)
    -- ยกตัวอย่างพรีวิวแบบ local-only และล็อกตำแหน่ง
    previewVeh = CreateVehicle(joaat(model), spot.x, spot.y, spot.z, spot.w, false, true)
    SetEntityCollision(previewVeh, false, false)
    FreezeEntityPosition(previewVeh, true)
    SetVehicleOnGroundProperly(previewVeh)
    -- กล้องพรีวิว
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
        options[#options+1] = {
            title = ('%s | ค่าปลด %d'):format(v.plate, v.impound_fee or 0),
            description = ('%s'):format(model),
            arrow = true,
            onSelect = function()
                local spot = findFreeSpot(garage.spawn)
                if not spot then
                    lib.notify({ title = 'ไม่มีที่ว่าง', type = 'error' })
                    return
                end
                showPreview(garage, model, spot)
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
                -- spawn after pay
                lib.requestModel(model)
                local veh = CreateVehicle(joaat(model), spot.x, spot.y, spot.z, spot.w, true, false)
                SetEntityAsMissionEntity(veh, true, true)
                SetVehicleOnGroundProperly(veh)
                SetVehicleNumberPlateText(veh, v.plate)
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
        openImpoundMenu(garage)
        return
    end

    local vehicles = lib.callback.await('esx_garage:getPlayerVehicles', false, garage.id)
    local options = {}

    -- เก็บรถคันที่นั่งอยู่
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
                local ok = lib.callback.await('esx_garage:storeVehicle', false, plate, garage.id)
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
        local status = (v.stored == 1 and 'IN' or 'OUT')
        options[#options+1] = {
            title = ('%s [%s]'):format(v.plate, status),
            description = name,
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
                showPreview(garage, (v.vehicle and v.vehicle.model) or 'adder', spot)
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

-- ปุ่มเปิดเมนูเมื่อยืนในโซน (fallback)
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

-- เฝ้ารถที่สปอว์นจาก garage ถ้าหาย/พัง ให้ impound อัตโนมัติ
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
