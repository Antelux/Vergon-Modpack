#!/bin/bash

echo -e 'Material Modifier ID\tMaterial Modifier Name\r'
echo -e '==============================================\r'

cat tiles/materials/*.material tiles/mods/gemspark/*.matmod tiles/mods/gemstone/*.matmod tiles/mods/ore/*.matmod tiles/mods/racial/*.matmod tiles/mods/wacky/*.matmod |grep -e modId -e modName |tr -d '\n' |tr -d '\r' |tr -d ' '  |sed 's/\"modId\"\://g' |sed 's/,\"modName\"\:\"/\t\t\t/g' |sed 's/\"\,/\r\n/g' |sort
