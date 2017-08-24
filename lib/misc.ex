defmodule Misc do
    alias Nostrum.Api
    @moduledoc """
    Miscellaneous commands
    """
    defmacrop funcs do
      quote do
        __MODULE__.__info__(:functions)
        |> Enum.map(fn {k, _} -> {Atom.to_string(k), k} end)
        |> Map.new
        |> Map.delete("list_funcs")
      end
    end

    def list_funcs do
        funcs()
    end

    @doc """
    This command. Get help on other commands. Usage: `nb!help` or `nb!help <command>`
    """
    def help(msg, [], state) do
      message = Enum.reduce(ElixirBot.cogs, "```", fn cog, acc ->
        commands = (for {{func, _arity}, _num, _type, _args, doc} <- Code.get_docs(cog, :docs) do
          if doc, do: "\t#{Atom.to_string(func)}: #{doc}"
        end)
        |> Enum.filter(fn x -> x end)
        |> Enum.join
        {_, doc} = Code.get_docs(cog, :moduledoc)
        acc <> "#{Atom.to_string(cog) |> String.replace_prefix("Elixir.", "")}: #{doc}#{commands}"
      end) <> "\n```"
      Api.create_message(msg.channel_id, Application.get_env(:elixirbot, :desc) <> message)
      {:ok, state}
    end

    def help(msg, [command], state) do
      {cog, func} = ElixirBot.commands[command]
      {{func, _arity}, _num, _type, _args, doc} = Code.get_docs(cog, :docs)
      |> Enum.find(nil, fn {{f, _arity}, _num, _type, _args, _doc} -> f == func end)

      message = "```elixir\n#{command}:\n\t#{doc}\n```"
      Api.create_message(msg.channel_id, message)
      {:ok, state}
    end

    @doc """
    Get info on a member. Usage: nb!memberinfo <user mention>
    """
    def memberinfo(msg, [], state) do
      if String.replace_prefix(msg.content, ElixirBot.prefix <> "memberinfo", "") == "" do
        Api.create_message(msg.channel_id, "You need to have a member!")
      else
        channel = Api.get_channel!(msg.channel_id)
        guild = Api.get_guild!(channel["guild_id"])

        resp = msg.content
        |> String.replace_prefix(ElixirBot.prefix <> "memberinfo ", "")
        |> Utils.parse_name(channel["guild_id"])

        case resp do
          {:ok, user} ->
            author = %{url: user["user"]["avatar_url"], name: user["user"]["username"]}
            thumbnail = %{url: user["user"]["avatar_url"]}

            roles = for id <- user["roles"], do: Utils.get_id(guild.roles, id)["name"]

            fields = [
              %{name: "Name", value: user["user"]["username"]},
              %{name: "Discrim", value: user["user"]["discriminator"]},
              %{name: "ID", value: user["user"]["id"]},
              %{name: "Joined", value: user["joined_at"]},
              %{name: "Roles", value: Enum.join(roles, ", ")},
              %{name: "Avatar", value: "[Link](#{user["user"]["avatar_url"]})"}
            ]

            embed = %{author: author, fields: fields, thumbnail: thumbnail}

            Api.create_message(msg.channel_id, [content: "", embed: embed])

          {:error, reason} ->
            Api.create_message(msg.channel_id, reason)
        end
      end
      {:ok, state}
    end

    @doc """
    Get info on the bot
    """
    def info(msg, [], state) do
      user = msg.author

      channel = Api.get_channel!(msg.channel_id)

      author = %{url: user["user"]["avatar_url"], name: user["user"]["username"]}
      thumbnail = %{url: user["user"]["avatar_url"]}


      uptime = ElixirBot.start_time |> Timex.format!("{relative}", :relative)

      fields = [
        %{name: "Author", value: "Henry#6174 (Discord ID: 122739797646245899)"},
        %{name: "Library", value: "Nostrum (Elixir)"},
        %{name: "Uptime", value: uptime},
        %{name: "Servers", value: Nostrum.Cache.Guild.GuildServer.all |> Enum.count |> to_string},
        %{name: "Source", value: "[Github](https://github.com/henry232323/ElixirBot)"},
      ]

      embed = %{author: author, fields: fields, thumbnail: thumbnail}

      Api.create_message(msg.channel_id, [content: "", embed: embed])

      {:ok, state}
    end
end
