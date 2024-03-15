#!/bin/bash

module_name=$1
set -e

# if module_name is empty, update all modules
if [ -z "$module_name" ]; then
    git submodule update --remote --recursive
    exit 0
fi

module_path="aur-pkgs/$module_name"
git submodule update --remote "$module_path"
