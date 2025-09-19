Config = {}

-- Inventory
Config.UseOxInventory = true

-- Plate "AAA 111"
Config.PlatePattern = '^%u%u%u %d%d%d$'

-- Spawn safety
Config.SpawnDistanceCheck = 5.0   -- ต้องว่างอย่างน้อย X เมตร
Config.DespawnOnStore     = true

-- Allow only cars (ban list by class)
Config.ForbidVehicleClasses = {
  [8]=true,[13]=true,[14]=true,[15]=true,[16]=true,[21]=true
}

-- Impound
Config.Impound = {
  Enabled = true,
  Jobs = { 'police' },  -- เพิ่มได้
  MinFee = 100,
  MaxFee = 100000,
  DefaultHours = 4,
  GarageId = 'impound_public'
}

-- Garages (เพิ่มได้ไม่จำกัด)
Config.Garages = {
  {
    id='legion_public', label='Legion Public Garage', type='public',
    coord=vec3(215.8, -810.1, 30.7), heading=160.0,
    spawn={ vec4(223.1,-804.6,30.6,157.5), vec4(226.5,-802.0,30.6,157.5) },
    previewCamOffset=vec3(3.0,3.0,1.5)
  },
  {
    id='impound_public', label='City Impound', type='impound',
    coord=vec3(401.9, -1631.1, 29.3), heading=230.0,
    spawn={ vec4(409.2,-1637.5,29.2,230.0) }
  }
}
