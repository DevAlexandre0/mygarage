local ESX = exports['es_extended']:getSharedObject()

-- ใช้งานไอเท็มสัญญา
ESX.RegisterUsableItem(Config.ContractItem, function(source)
  TriggerClientEvent('esx_garage:contract:use', source)
end)

-- โอนรถให้ผู้เล่น
lib.callback.register('esx_garage:contract:transfer', function(source, data)
  local seller = ESX.GetPlayerFromId(source); if not seller then return { ok=false, reason='no_seller' } end
  local buyer  = ESX.GetPlayerFromId(tonumber(data.target) or -1); if not buyer then return { ok=false, reason='no_buyer' } end

  local plate  = string.upper(data.plate or '')
  if not plate:match('^%u%u%u %d%d%d$') then return { ok=false, reason='plate' } end

  local row = MySQL.single.await('SELECT owner, impounded FROM owned_vehicles WHERE plate=?', { plate })
  if not row then return { ok=false, reason='notfound' } end
  if row.owner ~= seller.getIdentifier() then return { ok=false, reason='not_owner' } end
  if row.impounded == 1 then return { ok=false, reason='impounded' } end

  -- ระยะใกล้ ≤ 10.0
  local sPos = GetEntityCoords(GetPlayerPed(source))
  local bPos = GetEntityCoords(GetPlayerPed(buyer.source))
  if #(sPos - bPos) > 10.0 then return { ok=false, reason='too_far' } end

  -- ชำระเงิน
  local price = math.max(tonumber(data.price or 0), 0)
  local account = Config.PayAccount or 'bank'
  if account == 'money' then
    if buyer.getMoney() < price then return { ok=false, reason='notenough' } end
    buyer.removeMoney(price); seller.addMoney(price)
  else
    if buyer.getAccount(account).money < price then return { ok=false, reason='notenough' } end
    buyer.removeAccountMoney(account, price); seller.addAccountMoney(account, price)
  end

  -- โอนกรรมสิทธิ์
  MySQL.update.await('UPDATE owned_vehicles SET owner=?, stored=1 WHERE plate=?', { buyer.getIdentifier(), plate })

  -- ลบไอเท็มสัญญาจากผู้ขาย
  seller.removeInventoryItem(Config.ContractItem, 1)

  TriggerClientEvent('ox_lib:notify', seller.source, { title='Contract', description=('ขาย %s ให้ %s สำเร็จ'):format(plate, buyer.getName()), type='success' })
  TriggerClientEvent('ox_lib:notify', buyer.source,  { title='Contract', description=('ได้รับ %s จาก %s'):format(plate, seller.getName()), type='success' })

  return { ok=true }
end)
