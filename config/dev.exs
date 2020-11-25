use Mix.Config

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :tds,
  opts: [hostname: "nitrox", username: "sa", password: "some!Password", database: "test", ssl: true, ssl_opts: [certfile: "/Users/mjaric/prj/github/tds/mssql.pem", keyfile: "/Users/mjaric/prj/github/tds/mssql.key"]]
