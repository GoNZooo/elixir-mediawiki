# Mediawiki
Mediawiki API bindings for elixir.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add mediawiki to your list of dependencies in `mix.exs`:

        def deps do
          [{:mediawiki, :github "GoNZooo/elixir-mediawiki", :tag "0.0.1"}]
        end

  2. Ensure mediawiki is started before your application:

        def application do
          [applications: [:mediawiki]]
        end
