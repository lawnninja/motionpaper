#!/bin/sh
set -eu

expect() {
    grep -q "$1" "$2" || {
        echo "missing: $1 in $2" >&2
        exit 1
    }
}

expect '^default = "none"$' motionpaper/plugin.toml
expect 'hidden = "none"' motionpaper/service.luau
expect '#hiddenFlags("none") == 0' motionpaper/service.luau

echo "hidden playback default: passed"
