name 'Prospecting'
author 'glitchdetector'
contact 'glitchdetector@gmail.com'

fx_version 'adamant'
game 'gta5'

lua54 'yes'

description 'Prospect for treasure in key locations'
details [[
    Inspired by the Prospect minigame in MySims
    Metal detector model by Vartanyan
    https://www.turbosquid.com/3d-models/3d-metal-detector/1138741
    Converted by glitchdetector
    Yes, I did actually buy it for $11
]]

shared_scripts{
    '@ox_lib/init.lua',
    "config.lua",
}

client_script 'scripts/cl_*.lua'
server_scripts {
    'scripts/sv_*.lua',
    'interface.lua',
}

file 'stream/gen_w_am_metaldetector.ytyp'

data_file 'DLC_ITYP_REQUEST' 'stream/gen_w_am_metaldetector.ytyp'

server_exports {
    'AddProspectingTarget', -- x, y, z, data
    'AddProspectingTargets', -- list
    'StartProspecting', -- player
    'StopProspecting', -- player
    'IsProspecting', -- player
    'SetDifficulty', -- modifier
}
