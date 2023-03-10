#!/bin/bash

grep "127.0.0.1 www.localhost img.localhost" /etc/hosts || echo 127.0.0.1 www.localhost img.localhost | tee -a /etc/hosts