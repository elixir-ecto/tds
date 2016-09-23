use Mix.Config

config :logger, level: :info

config :mssql,
  opts: [
    hostname: "sql.server",
    instance: "test",
    username: "test_user",
    password: "test_password",
    database: "test"
  ]

