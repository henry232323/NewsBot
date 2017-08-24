defmodule News do
    alias Nostrum.Api
    @moduledoc """
    News type commands
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
    Usage: `nb!pol` Get a random post from /pol/
    """
    def pol(msg, _, state) do
        Api.start_typing(msg.channel_id)
        response = HTTPoison.get!("https://a.4cdn.org/pol/catalog.json").body
        [api | _] = Poison.Parser.parse!(response)
        html = Enum.random(api["threads"])["com"]
        final = HtmlSanitizeEx.strip_tags(html)
        {:ok, message} = Api.create_message(msg.channel_id, final)
        :timer.sleep(60000)
        Api.delete_message(message)

        {:ok, state}
    end

    @doc """
    Subscribe a channel to news source(s). Usage: nb!subscribe <channel mention> [*sources]
    """
    def subscribe(msg, [channel | sources], intstate) do
      state = GenServer.call(Subscriptions, :get_state)
      channel_id = channel
                   |> String.replace_prefix("<#", "")
                   |> String.replace_suffix(">", "")

      allsources = HTTPoison.get!("https://newsapi.org/v1/sources?apiKey=3038b939163a4c7f864ee6e532a3d48e", [], [ssl: [{:versions, [:'tlsv1.2']}]]).body
                |> Poison.Parser.parse!
      allsources = allsources["sources"]
      parts = for source <- allsources, do: source["id"]
      if Enum.all?(sources, fn x -> x in parts end) do
        if Map.has_key?(state, channel_id) do
          sources = state[channel_id] ++ sources
        end
        state = Map.merge(state, %{String.to_integer(channel_id) => sources})
        Api.create_message(msg.channel_id, "Successfully subscribed to #{Enum.join(sources, ", ")} in #{channel}")
        GenServer.cast(Subscriptions, {:update, state})
        {:ok, intstate}
      else
        Api.create_message(msg.channel_id, "Gave an invalid source!")
        {:ok, intstate}
      end
    end

    @doc """
    Get a list of news sources to subscribe to. Usage: `nb!sources` or `nb!sources <category>`
    """
    def sources(msg, [], state) do
      sources = HTTPoison.get!("https://newsapi.org/v1/sources?apiKey=3038b939163a4c7f864ee6e532a3d48e", [], [ssl: [{:versions, [:'tlsv1.2']}]]).body
                |> Poison.Parser.parse!
      sources = sources["sources"]
      parts = for source <- sources, do: source["id"]
      final = "Valid sources:\n" <> Enum.join(parts, ", ")
      Api.create_message!(msg.channel_id, final)
      {:ok, state}
    end

    def sources(msg, [category], state) do
      sources = HTTPoison.get!("https://newsapi.org/v1/sources?apiKey=3038b939163a4c7f864ee6e532a3d48e&category=#{category}", [], [ssl: [{:versions, [:'tlsv1.2']}]]).body
                |> Poison.Parser.parse!
      sources = sources["sources"]
      parts = for source <- sources, do: source["id"]
      final = "Valid sources:\n" <> Enum.join(parts, ", ")
      Api.create_message!(msg.channel_id, final)
      {:ok, state}
    end

    @doc """
    Get a list of subscriptions for the server. Usage: `nb!subscriptions`
    """
    def subscriptions(msg, [], intstate) do
      state = GenServer.call(Subscriptions, :get_state)
      {:ok, channels} = msg.channel_id
              |> Api.get_channel!
              |> Access.get("guild_id")
              |> Api.get_channels

      fmsg = (for chan <- channels do
        if Map.has_key?(state, chan["id"]) do
          "<##{to_string(chan["id"])}>: " <> Enum.join(state[chan["id"]], ", ")
        end
      end)
      |> Enum.filter(fn x -> x end)
      |> Enum.join("\n\t")

      final = "Subscriptions for this server:\n\t" <> fmsg
      Api.create_message(msg.channel_id, final)
      {:ok, intstate}
    end

    @doc """
    Unsubscribe a channel from news source(s). Usage: `nb!unsubscribe [*sources]`
    """
    def unsubscribe(msg, [channel | sources], intstate) do
      state = GenServer.call(Subscriptions, :get_state)
      channel_id = channel
                   |> String.replace_prefix("<#", "")
                   |> String.replace_suffix(">", "")

      if !Map.has_key?(state, channel_id) do
        Api.create_message(msg.channel_id, "This channel isnt subscribed to anything!")
      else
        newstate = %{state | channel_id => Enum.filter(state[channel_id], fn x -> !(x in sources) end) }
        GenServer.cast(Subscriptions, {:update, newstate})
        Api.create_message(msg.channel_id, "Unsubscribed from #{Enum.join(sources, ", ")}, still subscribed to #{Enum.join(state[channel_id], ", ")} in #{channel}")
      end
      {:ok, intstate}
    end
end
