defmodule RemitWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :remit

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    max_age: 9_999_999_999,  # A long time.
    key: "_remit_key",
    signing_salt: "ndGdfBhJ"
  ]

  # See app.js for details.
  socket "/socket", RemitWeb.UserSocket,
    websocket: [timeout: 45_000]  # Timeout for Heroku: https://hexdocs.pm/phoenix/heroku.html#making-our-project-ready-for-heroku

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [
      websocket: [timeout: 45_000],  # Timeout for Heroku: https://hexdocs.pm/phoenix/heroku.html#making-our-project-ready-for-heroku
      connect_info: [session: @session_options],
    ]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :remit,
    gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :remit
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug RemitWeb.Router
end
