use Mix.Config

config :logger, level: :info

config :tds,
  opts: [
    hostname: "127.0.0.1",
    username: "sa",
    password: "some!Password",
    database: "test"
  ]

