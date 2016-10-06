#!/bin/bash
systemctl stop redis docker.redis demo-api-redis@{1..6} balance docker.balance
systemctl disable redis docker.redis demo-api-redis@{1..6} balance docker.balance
/home/luke/Development/pixelscamp-talk-20161007/scripts/copy.sh 1
systemctl daemon-reload
