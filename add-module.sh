#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <module_name>"
    exit 1
fi

module_name=$1
module_path="aur-pkgs/$module_name"
module_url="https://aur.archlinux.org/$module_name.git"

if [ -d "$module_path" ]; then
    echo "Module $module_name already exists"
    exit 1
fi

git submodule add -f "$module_url" "$module_path"
