#!/bin/sh

xo-cli user.getAll --json | jq -r '.[] | select(.email == "admin") | .id'