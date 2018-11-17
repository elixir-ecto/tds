use Mix.Config

config :logger, level: :debug

config :tds,
  opts: [
    hostname: System.get_env("SQL_HOSTNAME") || "127.0.0.1",
    username: System.get_env("SQL_USERNAME") || "sa",
    password: System.get_env("SQL_PASSWORD") || "some!Password",
    database: "test",
    set_allow_snapshot_isolation: :on
  ]
