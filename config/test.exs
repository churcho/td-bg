use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :td_bg, TdBgWeb.Endpoint,
  http: [port: 4002],
  server: true

# Hashing algorithm just for testing porpouses
config :td_bg, hashing_module: TdBg.DummyHashing

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :td_bg, TdBg.Repo,
  username: "postgres",
  password: "postgres",
  database: "td_bg_test",
  hostname: "postgres",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1

config :td_bg, :audit_service, api_service: TdBgWeb.ApiServices.MockTdAuditService

config :td_bg, permission_resolver: TdBg.Permissions.MockPermissionResolver

config :td_bg, metrics_publication_frequency: 1000

config :td_cache, redis_host: "redis"

config :td_bg, TdBg.Search.Cluster, api: TdBg.ElasticsearchMock

config :td_cache, :event_stream, streams: []
