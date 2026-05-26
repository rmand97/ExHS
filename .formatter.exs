[
  import_deps: [
    :ash_admin,
    :ash_authentication_phoenix,
    :ash_authentication,
    :ash_events,
    :ash_postgres,
    :ash_phoenix,
    :ash,
    :reactor,
    :ecto,
    :ecto_sql,
    :phoenix
  ],
  subdirectories: ["priv/*/migrations"],
  plugins: [Spark.Formatter, Phoenix.LiveView.HTMLFormatter],
  attribute_formatters: %{class: CanonicalTailwind},
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"]
]
