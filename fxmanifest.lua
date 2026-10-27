fx_version 'cerulean'
game 'gta5'

name 'qbx_universal_safezone'
description '汎用セーフゾーンスクリプト（病院・飲食店・共用施設対応）'
author 'otonashi'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

lua54 'yes'
