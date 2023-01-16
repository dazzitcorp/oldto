#!/bin/bash
git ls-files pipeline .py | grep -v '_test' | grep -v '.md5' |  xargs vulture whitelist.py
