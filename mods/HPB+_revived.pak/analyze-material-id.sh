#!/bin/bash

echo -e 'Material ID\t\tMaterial Name\r'
echo -e '=====================================\r'

cat tiles/materials/*.material tiles/platforms/*.material tiles/macrochips/*.material |grep -e materialId -e materialName |tr -d '\n' |tr -d '\r' |tr -d ' '  |sed 's/\"materialId\"\://g' |sed 's/,\"materialName\"\:\"/\t\t\t/g' |sed 's/\"\,/\r\n/g' |sort
