Config = {}

-- การตั้งค่า ESX/Inventory
Config.UseOxInventory = true -- บังคับเชื่อม ox_inventory

-- รูปแบบป้ายทะเบียนของเซิร์ฟเวอร์
Config.PlatePattern = '^%u%u%u %d%d%d$' -- "AAA 111"

-- การตั้งค่าการสปอว์นและป้องกัน
Config.SpawnDistanceCheck = 25.0
Config.DespawnOnStore = true

-- รองรับเฉพาะรถยนต์ (กรองด้วย Vehicle Class client-side)
Config.ForbidVehicleClasses = { [8]=true, [13]=true, [14]=true, [15]=true, [16]=true, [21]=true } -- ห้าม: มอเตอร์ไซค์, จักรยาน, เรือ, ฮ. เครื่องบิน, รถไฟ

-- ค่าปริยาย impound
Config.Impound = {
  Enabled = true,
  Jobs = { 'police' },  -- เพิ่ม/แก้ได้
  MinFee = 100,
  MaxFee = 100000,
  DefaultHours = 4,
  GarageId = 'impound_public' -- virtual impound; ปล่อยรถได้จากเมนูทุกจุด
}

-- ตัวอย่างจุดจอด
Config.Garages = {
  {
    id = 'legion_public',
    label = 'Legion Public Garage',
    type = 'public',
    coord = vec3(215.8, -810.1, 30.7),
    heading = 160.0,
    spawn = {
      vec4(223.1, -804.6, 30.6, 157.5),
      vec4(226.5, -802.0, 30.6, 157.5)
    },
    previewCamOffset = vec3(3.0, 3.0, 1.5)
  }
}
