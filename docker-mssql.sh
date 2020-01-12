#!/bin/bash

docker run \
  --name test_mssql_server
  -e 'ACCEPT_EULA=Y' \
  -e 'SA_PASSWORD=some!Password' \
  -p 1433:1433 \
  -d microsoft/mssql-server-linux:latest
