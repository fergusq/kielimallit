#!/bin/zsh

pandoc -f markdown-smart -t ms -o ${1:r}.pdf $1
