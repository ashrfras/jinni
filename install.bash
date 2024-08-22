#!/bin/bash

#tar -czvf jinni.tar.gz ئساسية ErrorManager.js ImportManager.js jinni jparser.js Scope.js Symbol.js SymbolScopes.js template.html

#download jinni tarball
#download jiss tarball
wget https://raw.githubusercontent.com/ashrfras/jinni/main/jinni.tar.gz
#wget https://raw.githubusercontent.com/ashrfras/jiss/main/jiss.tar.gz

#extract jinni tarball
#extract jiss tarball
mkdir /opt/jinni
tar -xzvf jinni.tar.gz -C /opt/jinni
#tar -xzvf jiss.tar.gz -C /opt/jinni/jiss

#create simlink of jinni and jiss to /bin folder
sudo ln -s /opt/jinni/jinni /usr/bin/jinni
#sudo ln -s /opt/jinni/jiss/jiss /usr/bin/jiss

#make it executable
sudo chmod +x /usr/bin/jinni
#sudo chmod +x /ust/bin/jiss