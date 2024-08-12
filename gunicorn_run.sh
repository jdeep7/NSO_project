#!/bin/bash
sudo gunicorn --config ~/g_unicorn_config.py app:app
