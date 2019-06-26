#!/bin/sh

rm -r build
mkdir -p build/demot
~/.bilar/bin/siteplan
rsync -av static/* build

