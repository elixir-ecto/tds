defmodule Mix.Tasks.Docker.Compose do
  use Mix.Task

  @shortdoc "Runs docker compose up/down via Mix with optional platform-aware profiles"

  @default_compose "docker-compose.yml"
  @amd64_profile "mssql_amd64"
  @arm64_profile "mssql_arm64"

  @moduledoc """
  CLI wrapper around **docker compose** for starting and stopping development services.

  ## Commands

    - `mix docker.compose up`
    - `mix docker.compose down`

  The `up` command always runs in **detached mode** (`docker compose ... up -d`).
  The `down` command stops all services (`docker compose ... down`).

  ---

  ## Options

    - **`-f`, `--file PATH`**
      Use a specific compose file instead of the default:

          mix docker.compose up -f docker-compose.test.yml

    - **`-p`, `--profile NAME`**
      Use a specific compose profile:

          mix docker.compose up --profile mssql_amd64

  ---

  ## Profile selection rules

  If no `-f/--file` is provided:

    - `docker-compose.yml` is used
    - if no `--profile` is given:
        - the profile is auto-selected based on host architecture:
            - mssql_arm64 on ARM / Apple Silicon
            - mssql_amd64 on x86_64
    - if `--profile` is given:
        - that profile is used explicitly

  If `-f/--file` is provided:

    - that compose file is used
    - if no `--profile` is given:
        - no `--profile` flag is passed to Docker
    - if `--profile` is given:
        - that profile is passed to Docker

  ---

  ## Examples

  Basic usage (auto-selected profile):

      mix docker.compose up
      mix docker.compose down

  Custom compose file:

      mix docker.compose up -f docker-compose.test.yml
      mix docker.compose down -f docker-compose.test.yml

  Explicit profile:

      mix docker.compose up --profile mssql_amd64
  """

  def run(args) do
    {opts, rest, has_file?} = parse_args(args)

    compose_file = opts[:file] || @default_compose
    docker = find_docker!()

    profile = select_profile(opts, has_file?)

    case rest do
      ["up"] ->
        # up je UVEK detached
        run_compose(docker, compose_file, profile, ["up"], true)

      ["down"] ->
        run_compose(docker, compose_file, profile, ["down"], false)

      [] ->
        Mix.shell().error("""
        No command provided. Expected: up | down

        Examples:
            mix docker.compose up
            mix docker.compose down
            mix docker.compose up -f docker-compose.dev.yml
        """)

      unknown ->
        Mix.shell().error("Unknown docker.compose command: #{inspect(unknown)}")
    end
  end

  # --------------------------------------------------------------------
  # Helpers
  # --------------------------------------------------------------------

  defp run_compose(docker, compose_file, profile, command, detach?) do
    profile_info =
      case profile do
        nil -> "no profile"
        p -> "profile=#{p}"
      end

    detach_info = if detach?, do: "detached", else: "attached"

    IO.puts(
      ">>> docker compose #{Enum.join(command, " ")} using #{compose_file} (#{profile_info}, #{detach_info})\n"
    )

    base_args = ["compose", "-f", compose_file]

    args =
      base_args
      |> maybe_add_profile(profile)
      # ["compose", "-f", ..., "up" | "down"]
      |> Kernel.++(command)
      |> maybe_add_detach(detach?)

    # output ide direktno na STDOUT, ne koristimo ga u kodu
    {_, status} = System.cmd(docker, args, into: IO.stream(:stdio, :line))

    if status != 0 do
      Mix.raise("docker compose #{Enum.join(command, " ")} failed with exit #{status}.")
    end
  end

  defp maybe_add_profile(args, nil), do: args
  defp maybe_add_profile(args, profile), do: args ++ ["--profile", profile]

  defp maybe_add_detach(args, true), do: args ++ ["-d"]
  defp maybe_add_detach(args, false), do: args

  defp find_docker! do
    case System.find_executable("docker") do
      nil -> Mix.raise("Could not find `docker` executable in PATH")
      path -> path
    end
  end

  # vraćamo i flag da li je prosleđen :file (da znamo da li je custom ili default)
  defp parse_args(args) do
    {opts, rest, _invalid} =
      OptionParser.parse(
        args,
        switches: [
          file: :string,
          profile: :string
        ],
        aliases: [
          f: :file,
          p: :profile
        ]
      )

    has_file? = Keyword.has_key?(opts, :file)
    {opts, rest, has_file?}
  end

  defp select_profile(opts, has_file?) do
    case opts[:profile] do
      # user eksplicitno prosledio profil → uvek koristimo
      profile when is_binary(profile) ->
        profile

      # nema --profile
      nil ->
        if has_file? do
          # custom -f → default je "bez profila"
          nil
        else
          # default file → auto-detekcija arhitekture
          arch =
            :erlang.system_info(:system_architecture)
            |> List.to_string()

          cond do
            String.contains?(arch, "arm") or String.contains?(arch, "aarch64") ->
              @arm64_profile

            true ->
              @amd64_profile
          end
        end
    end
  end
end
