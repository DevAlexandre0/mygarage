fx_version 'cerulean'
game 'gta5'

name 'esx_nfs_garage'
author 'Gesus'
version '1.0.0'

lua54 'yes'

dependencies {
  'es_extended',    -- ESX Legacy
  'oxmysql',
  'ox_lib'
}

shared_scripts {
  '@ox_lib/init.lua',
  'config.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/sv_garage.lua'
}

client_scripts {
  'client/cl_garage.lua'
}

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/style.css',
  'html/script.js'
}
