#!/bin/bash

python info21_web/manage.py makemigrations
python info21_web/manage.py migrate
python info21_web/manage.py runserver 0.0.0.0:8000