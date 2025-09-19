CreateThread(function()
  for _, g in ipairs(Config.Garages) do
    local cfg
    for _, b in ipairs(Config.Blips or {}) do
      if b.type == g.type then cfg = b break end
    end
    if cfg then
      local blip = AddBlipForCoord(g.coord.x, g.coord.y, g.coord.z)
      SetBlipSprite(blip, cfg.sprite or 50)
      SetBlipDisplay(blip, 4)
      SetBlipScale(blip, cfg.scale or 0.75)
      SetBlipColour(blip, cfg.color or 3)
      SetBlipAsShortRange(blip, true)
      BeginTextCommandSetBlipName('STRING'); AddTextComponentString(cfg.label or g.label); EndTextCommandSetBlipName(blip)
    end
  end
end)
