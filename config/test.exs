use Mix.Config

config :logger, level: :info

config :mssql,
  opts: [
    hostname: "localhost",
    username: "mssql",
    password: "mssql",
    database: "test"
  ]

