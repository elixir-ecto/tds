use Mix.Config

config :logger, level: :info

config :tds,
  opts: [
    hostname: "localhost",
    username: "sa",
    password: "some!Password",
    database: "test"
  ]

