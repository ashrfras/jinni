#!/bin/bash

#tar -czvf jinni.tar.gz ئساسية ErrorManager.js ImportManager.js jinni jparser.js Scope.js Symbol.js SymbolScopes.js template.html

#download jinni tarball
#download jiss tarball
rm -rf ~/.jinni
mkdir ~/.jinni
mkdir ~/.jinni/jiss
wget -P ~/.jinni https://github.com/ashrfras/jinni/raw/main/jinni.tar.gz
wget -P ~/.jinni/jiss https://github.com/ashrfras/JiSS/raw/master/jiss.tar.gz

#extract jinni tarball
#extract jiss tarball
tar -xzf ~/.jinni/jinni.tar.gz -C ~/.jinni
tar -xzf ~/.jinni/jiss/jiss.tar.gz -C ~/.jinni/jiss

mkdir ~/.jinni/bin
ln -s ~/.jinni/jinni ~/.jinni/bin/jinni
chmod +x ~/.jinni/bin/jinni

#add to PATH
line='export PATH="~/.jinni/bin:$PATH"'

# Check if the line is already present in .bashrc
if ! grep -q "$line" ~/.bashrc; then
    echo "$line" >> ~/.bashrc
	source ~/.bashrc
fi

#compile jiss
jinni --nowarning --norun ~/.jinni/jiss
#/home/ashras/jinni/jinni --nowarning --norun ~/.jinni/jiss