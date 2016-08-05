use Mix.Config

config :logger, level: :info

config :mssql,
  opts: [
    hostname: "192.168.11.101",
    instance: "test",
    username: "sa",
    password: "TalRs440866",
    database: "test"
  ]

