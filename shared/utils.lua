Utils = {}

function Utils.matchPlate(plate)
  return type(plate) == 'string' and plate:match(Config.PlatePattern) ~= nil
end

function Utils.canOpenVehicleInventory(src, plate, isPolice)
  -- เจ้าของหรือเป็นตำรวจ
  local row = MySQL.single.await('SELECT owner FROM owned_vehicles WHERE plate = ?', { plate })
  if not row then return false end
  if isPolice then return true end
  local ESX = exports['es_extended']:getSharedObject()
  local xPlayer = ESX.GetPlayerFromId(src)
  return xPlayer and xPlayer.getIdentifier() == row.owner
end
