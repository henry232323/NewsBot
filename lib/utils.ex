defmodule Utils do
    alias Nostrum.Api

    def parse_name(text, guild_id) do
      if String.starts_with?(text, "<@") and String.ends_with?(text, ">") do
        id = text
        |> String.replace_prefix("<@", "")
        |> String.replace_suffix(">", "")
        |> String.replace_prefix("!", "")

        Api.get_member(guild_id, id)
      else
        guild = Api.get_guild!(guild_id).members
        |> get(name: text)
      end
    end

    def get_id(enum, id) do
      enum
      |> Enum.find(fn i -> i["id"] == id end)
    end

    def get(enum, args \\ []) do
      [attribute | [value | _]] = args

      enum
      |> Enum.find(fn i -> Map.from_struct(i)[attribute] == value end)
    end

    def get_all(enum, args \\ []) do
      [attribute | [value | _]] = args

      enum
      |> Enum.filter(fn i -> Map.from_struct(i)[attribute] == value end)
    end

    def create_msg(content) do
      {:ok, author} = Api.get_user(122739797646245899)
      message = %Nostrum.Struct.Message{attachments: [], author: author,
       channel_id: 166687679021449216, content: content, edited_timestamp: "",
       embeds: [], id: 0, mention_everyone: false, mention_roles: [],
       mentions: [], nonce: 0, pinned: false, timestamp: "",
       tts: false, type: 0}

      ElixirBot.handle_event({:MESSAGE_CREATE, {message}, nil}, nil)
    end
end
