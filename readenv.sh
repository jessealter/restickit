#!/bin/bash

# Check if the script was sourced
if [ "$0" = "${BASH_SOURCE[0]}" ]; then
  echo "Run this command with source!"
  echo "Example:"
  echo "source $0 <filename>"
  exit 1
fi

if [[ -z "$1" ]]; then
    echo "Usage: $0 <filename>"
    return
fi

FILE="$1"

while read line; do
    if [[ "$line" =~ ^[^#].*= ]]; then
        export "$line"
    fi
done < "$FILE"
