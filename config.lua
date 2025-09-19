Config = {}

-- การตั้งค่า ESX/บัญชีชำระ
Config.UseOxInventory = false
Config.PayAccount = 'bank' -- 'bank' หรือ 'money'

-- การตั้งค่าการสปอว์นและป้องกัน
Config.SpawnDistanceCheck = 25.0
Config.DespawnOnStore = true

-- ป้ายทะเบียนเซิร์ฟเวอร์
Config.PlatePattern = 'AAA 111' -- ตรวจด้วย ^%u%u%u %d%d%d$

-- Impound
Config.Impound = {
  Enabled = true,
  Jobs = { 'police' },   -- เพิ่มได้ในนี้
  MinFee = 100,
  MaxFee = 100000,
  AutoFee = 100,         -- ค่าปลดเมื่อ auto-impound (ปรับได้)
  GarageId = 'impound_public'
}

-- ตัวอย่างจุดจอดไม่จำกัด
Config.Garages = {
  {
    id = 'legion_public',
    label = 'Legion Public Garage',
    type = 'public',
    coord = vec3(215.8, -810.1, 30.7),
    heading = 160.0,
    spawn = {
      vec4(223.1, -804.6, 30.6, 157.5),
      vec4(226.5, -802.0, 30.6, 157.5),
      vec4(229.6, -799.8, 30.6, 157.5)
    },
    previewCamOffset = vec3(3.0, 3.0, 1.5)
  },
  {
    id = 'impound_public',
    label = 'City Impound',
    type = 'impound',
    coord = vec3(409.2, -1623.2, 29.3),
    heading = 230.0,
    spawn = {
      vec4(402.8, -1643.8, 29.3, 230.0),
      vec4(398.5, -1646.7, 29.3, 230.0)
    },
    previewCamOffset = vec3(4.0, 3.0, 1.8)
  }
}
