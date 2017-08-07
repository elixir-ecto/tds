use Mix.Config

config :logger, level: :info

config :mssql,
  opts: [
    hostname: "localhost",
    username: "sa",
    password: "some!Password",
    database: "test"
  ]

