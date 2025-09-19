Config = {}

-- ชื่อตารางตามที่กำหนด
Config.VehicleTable = 'owned_vehicle'

-- จุดเข้า/ออกหลายตำแหน่ง
Config.Garages = {
  -- NFS Heat style: ช่องจอดหน้าโรงรถ
  {
    id = 'pillbox_garage',
    label = 'Garage A',
    enter = vec3(215.124, -791.294, 30.80),
    spawn = vec4(222.68, -804.32, 30.61, 248.0),
    radius = 2.0,
    blip = { sprite = 357, color = 3, scale = 0.7 }
  },
  {
    id = 'vespucci_garage',
    label = 'Garage B',
    enter = vec3(-1153.36, -1990.68, 13.18),
    spawn = vec4(-1156.92, -2004.32, 13.18, 316.0),
    radius = 2.0,
    blip = { sprite = 357, color = 3, scale = 0.7 }
  }
}

-- ป้องกันสแปมสลับรถ
Config.SwitchCooldown = 3000 -- ms

-- โหมดดีบัก
Config.Debug = true
