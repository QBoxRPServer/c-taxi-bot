fx_version 'cerulean'
game 'common'
lua54 'yes'
author 'Cruso'
version '0.1.0'
description 'Taxi bot. Citra-taxi ideas used'

client_script {
    'client/*.lua',
    'client/classes/*.lua',
}
server_script {
    'server/*.lua',
    --'server/classes/*.lua',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

