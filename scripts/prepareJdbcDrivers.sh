#!/bin/bash

echo "Copy JDBC Driver"

cp -rp /opt/helm/jdbc /driver-folder
chmod -R g+w /driver-folder/jdbc/*
ls -lR /driver-folder/jdbc/

echo "Done"