Utils = {}

function Utils.matchPlate(plate)
  return type(plate) == 'string' and plate:match(Config.PlatePattern) ~= nil
end

function Utils.isAllowedJob(xPlayer, jobs)
  if not xPlayer or not xPlayer.job then return false end
  local j = xPlayer.job.name
  for i=1,#jobs do if jobs[i] == j then return true end end
  return false
end
