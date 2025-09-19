fx_version 'cerulean'
game 'gta5'

name 'esx_garage'
description 'Global ESX Garage with zones/points, fixed-price impound, active map, contract, blips'
version '0.3.0'
lua54 'yes'

shared_scripts {
  '@ox_lib/init.lua',
  'config.lua',
  'shared/*.lua'
}

client_scripts {
  'client/main.lua',
  'client/blips.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua',
  'server/contract.lua'
}

dependencies {
  'es_extended',
  'ox_lib',
  'oxmysql'
}
