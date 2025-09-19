Config = {}

-- การตั้งค่า ESX/Inventory
Config.UseOxInventory = false -- ตั้ง 'true' เมื่อเชื่อมกับ ox_inventory และ ESX >= 1.6.0

-- การตั้งค่าการสปอว์นและป้องกัน
Config.SpawnDistanceCheck = 25.0 -- กัน pileup ใกล้จุดจอด
Config.DespawnOnStore = true

-- ค่าปริยาย impound
Config.Impound = {
  Enabled = true,
  Jobs = { 'police', 'mechanic' }, -- ผู้มีสิทธิ์ยึด/ปล่อย
  MinFee = 500,
  MaxFee = 5000,
  DefaultHours = 4
}

-- ตัวอย่างจุดจอดไม่จำกัด
Config.Garages = {
  -- ตัวอย่าง public garage แบบ target + เมนู
  {
    id = 'legion_public',
    label = 'Legion Public Garage',
    type = 'public', -- public / job / house
    coord = vec3(215.8, -810.1, 30.7),
    heading = 160.0,
    spawn = {
      vec4(223.1, -804.6, 30.6, 157.5),
      vec4(226.5, -802.0, 30.6, 157.5)
    },
    previewCamOffset = vec3(3.0, 3.0, 1.5)
  }
}
