fx_version 'cerulean'
game 'gta5'

name 'esx_garage'
description 'ESX Garage with ox_lib/ox_target/oxmysql/ox_inventory'
version '0.2.0'
lua54 'yes'

shared_scripts {
  '@ox_lib/init.lua',
  'config.lua',
  'shared/*.lua'
}

client_scripts {
  'client/*.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/*.lua'
}

dependencies {
  'es_extended',
  'ox_lib',
  'oxmysql',
  'ox_target',
  'ox_inventory'
}
