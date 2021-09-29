#!/bin/bash

docker run \
  -e 'ACCEPT_EULA=Y' \
  -e 'SA_PASSWORD=some!Password' \
  -p 1433:1433 \
  -d mcr.microsoft.com/azure-sql-edge:latest
  # -d mcr.microsoft.com/mssql/server:2019-latest
