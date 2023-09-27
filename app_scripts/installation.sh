#!/bin/bash

apt-get update && apt-get upgrade -y
pip install --no-cache-dir -r requirements.txt
