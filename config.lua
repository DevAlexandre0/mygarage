Config = {}

-- การเงิน
Config.PayAccount = 'bank'          -- 'bank' หรือ 'money'
Config.ImpoundPrice = 2500          -- ราคาเดียวทั้งระบบ

-- ทั่วไป
Config.PlatePattern = 'AAA 111'     -- ^%u%u%u %d%d%d$
Config.DespawnOnStore = true
Config.SpawnRadiusCheck = 3.5       -- กันสปอว์นทับ
Config.PositionUpdateInterval = 5000 -- ms อัปเดตพิกัด active

-- จุด Garage/Impound (global access)
Config.Garages = {
  {
    id='legion_public', label='Legion Public Garage', type='public',
    coord=vec3(215.8, -810.1, 30.7), heading=160.0,
    spawn={
      vec4(223.1, -804.6, 30.6, 157.5),
      vec4(226.5, -802.0, 30.6, 157.5),
      vec4(229.6, -799.8, 30.6, 157.5)
    }
  },
  {
    id='impound_public', label='City Impound', type='impound',
    coord=vec3(409.2, -1623.2, 29.3), heading=230.0,
    spawn={
      vec4(402.8, -1643.8, 29.3, 230.0),
      vec4(398.5, -1646.7, 29.3, 230.0)
    }
  }
}

-- Blips
Config.Blips = {
  { sprite=50,  color=3,  scale=0.75, label='Public Garage', type='public'  },
  { sprite=67,  color=1,  scale=0.75, label='Impound',       type='impound' },
}

-- ไอเท็มสัญญา
Config.ContractItem = 'veh_contract'
