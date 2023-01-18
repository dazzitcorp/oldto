#!/bin/bash
find pipeline/src -name '*.py' -print | grep -v '_test' |  xargs vulture
