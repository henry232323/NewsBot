defmodule ElixirBotSupervisor do
    use Application

    def start(_, _) do
      import Supervisor.Spec

      state = case(File.read("newsdata.json")) do
        {:ok, data} -> Poison.Parser.parse!(data)
                       |> Enum.map(fn x ->
                         case is_binary(x) and Subscriptions.numeric(x) do
                           true -> Integer.parse(x)
                           false -> x
                         end
                       end)
                       |> Enum.into(%{})
        {:error, _err} -> %{}
      end
      Task.start(&Subscriptions.start/0)

      children = [worker(Subscriptions, [state]) | (for i <- 1..System.schedulers_online, do: worker(ElixirBot, [], id: i))]

      Supervisor.start_link(children, strategy: :one_for_one)
    end
end

defmodule ElixirBot do
    use Nostrum.Consumer
    alias Nostrum.Api
    use Timex

    def start_link do
      Consumer.start_link(__MODULE__, :ok)
    end

    @start_time Timex.now
    @prefix Application.get_env(:elixirbot, :prefix)
    @owner_id Application.get_env(:elixirbot, :owner_id)
    @cogs Application.get_env(:elixirbot, :cogs)
    @commands @cogs
      |> Enum.map(fn cog -> {cog, apply(cog, :list_funcs, [])} end)
      |> Enum.flat_map(fn {cog, funcs} -> Enum.map(funcs, fn {k, v} -> {k, {cog, v}} end) end)
      |> Enum.into(%{})

    def prefix, do: @prefix
    def owner_id, do: @owner_id
    def commands, do: @commands
    def cogs, do: @cogs
    def start_time, do: @start_time

    def process_commands(msg, state) do
        [command | args] =
          msg.content
          |> String.replace_prefix(ElixirBot.prefix, "")
          |> OptionParser.split()

        if Map.has_key?(@commands, command) do
          {module, fun} = @commands[command]
          try do
            apply(module, fun, [msg, args, state])
          rescue
            e ->
              em = Map.from_struct(e)
              emsg = case em do
                %{"message": _} -> e.message
                %{"reason": _} -> e.reason
              end
              Api.create_message(msg.channel_id, emsg)
          end
        else
          Api.create_message(msg.channel_id, "That command does not exist!")
          {:ok, state}
        end
      end

    def handle_event({:READY, {map}, _ws_state}, state) do
      IO.puts("Logged in as " <> map.user.username)
      IO.puts("Currently running in " <> to_string(length(map.guilds)) <> " servers")
      Api.update_status(:online, "nb!help for help!")

      Task.start(__MODULE__, :start_usercount, [map.user.id, length(map.guilds)])
      {:ok, state}
    end

    def handle_event({:MESSAGE_CREATE, {msg}, _ws_state}, state) do
      if String.starts_with?(msg.content, @prefix) do
          Task.start(fn -> process_commands(msg, state) end)
      else
        {:ok, state}
      end
    end

    def handle_event(_, state) do
      {:ok, state}
    end

    def logout(state) do
      encoded = Poison.encode!(state)
      File.write("newsdata.json", encoded)
    end

    def start_usercount(id, guilds) do
      url = "https://bots.discord.pw/api/bots/#{id}/stats"
      {:ok, payload} = Poison.encode(%{server_count: guilds})
      dbots_headers = %{
        Authorization: Application.get_env(:elixirbot, :dbots_key),
        "Content-Type": "application/json"
      }
      HTTPoison.post(url, payload, dbots_headers, [ssl: [{:versions, [:'tlsv1.2']}]])
      :timer.sleep(3600000)
      start_usercount(id, Nostrum.Cache.Guild.GuildServer.all |> Enum.count)
    end
end

defmodule Subscriptions do
  use GenServer
  alias Nostrum.Api

  def start_link(state) do
    GenServer.start_link(Subscriptions, state, name: Subscriptions)
  end

  def numeric(str) do
    case Integer.parse(str) do
      {_num, ""} -> true
      _          -> false
    end
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:update, newstate}, _state) do
    {:noreply, newstate}
  end

  def handle_cast(:run, state) do
    srcs = (for {_id, types} <- state, do: types)
           |> Enum.filter(fn item -> is_list(item) end)
           |> List.flatten
           |> MapSet.new

    articles = for type <- srcs do
      json = HTTPoison.get!("https://newsapi.org/v1/articles?source=#{type}&sortBy=top&apiKey=3038b939163a4c7f864ee6e532a3d48e", [], [ssl: [{:versions, [:'tlsv1.2']}]]).body
             |> Poison.Parser.parse!
      [article | _] = json["articles"]
      if state[type] != article["title"] do
        {type, article}
      else
        {type, false}
      end
    end

    state = Enum.reduce(Enum.zip(srcs, articles), state, fn
      {type, {type, article}}, state ->
        if not (article in [false, nil]) and (state[type] != article["title"]) do
          Map.merge(state, %{type => article["title"]})
        else
          state
        end
    end)

    articles = Map.new(articles)
    for {id, sources} <- state do
      if is_number(id) or numeric(id) do
        for source <- sources do
          if articles[source] do
            article = articles[source]
            author = %{name: "By #{article["author"]} - #{source}"}
            image = %{url: article["urlToImage"]}
            footer = %{text: article["publishedAt"]}
            embed = %{author: author, title: article["title"], url: article["url"], description: article["description"], image: image, footer: footer}
            Api.create_message(id, [content: "", embed: embed])
          end
        end
      end
    end
    {:noreply, state}
  end

  def handle_cast(_cast, state) do
    {:noreply, state}
  end

  def start do
    :timer.sleep(:timer.minutes(20))
    GenServer.cast(__MODULE__, :run)
    start()
  end

end
