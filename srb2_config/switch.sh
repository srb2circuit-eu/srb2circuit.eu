#!/bin/bash
if [ "$1" == "chars" ]; then
    systemctl --user stop srb2
    systemctl --user start srb2_chars
else
    systemctl --user stop srb2_chars
    systemctl --user start srb2
fi
