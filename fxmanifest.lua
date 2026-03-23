fx_version 'cerulean'
game 'gta5'

name 'sh-park'
description 'Ferris Wheel & Roller Coaster - Lua OO with full player sync'
author 'shruog'
discord 'https://discord.gg/xddPEQEgUg'
repository 'https://github.com/shruog/sh-park'
original_repository 'https://github.com/Bluscream/LunaPark-FiveM'
version '2.0.0'

shared_scripts {
    'shared/config.lua',
    'shared/classes.lua',
}

client_scripts {
    'client/ferris_wheel.lua',
    'client/roller_coaster.lua',
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}
