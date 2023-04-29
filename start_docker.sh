#!/bin/bash

if [ "$(uname -m)" = "arm64" ]; then
  # Since mssql-server is not supported on arm64
  # see https://github.com/microsoft/mssql-docker/issues/668
  # this uses the azure-sql-edge image on that architecture
  IMAGE="mcr.microsoft.com/azure-sql-edge:latest"
  echo "Using azure-sql-edge image"
else
  IMAGE="mcr.microsoft.com/mssql/server:2022-latest"
  echo "Using mssql-server 2022 image"
fi

docker run \
  -e 'ACCEPT_EULA=Y' \
  -e 'SA_PASSWORD=some!Password' \
  -p 1433:1433 \
  --hostname mssql-server \
  --name mssql-server-2022 \
  -d $IMAGE

