fx_version 'cerulean'
game 'gta5'

author 'YourName'
description 'A resource to scan and verify prop existence and analyze furniture usage'
version '1.0.0'


shared_scripts {
    'config.lua'
}

client_scripts {    
    'client.lua'
}

server_scripts {
    'server.lua'
}

dependencies {
    'oxmysql'  -- Ensure oxmysql is installed and running
}