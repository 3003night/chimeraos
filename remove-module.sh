#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <module_name>"
    exit 1
fi

module_name=$1

module_path="aur-pkgs/$module_name"

if [ ! -d "$module_path" ]; then
    echo "Module $module_name does not exist"
    exit 1
fi

git submodule deinit -f "$module_path"
git rm -f "$module_path"
rm -rf "$module_path"
