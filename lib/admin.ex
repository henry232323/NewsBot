defmodule Admin do
    alias Nostrum.Api
    @moduledoc """
    Bot owner only functions
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
    Bot owner only. Evaluate Elixir code
    """
    def eval(msg, _, state) do
        if msg.author.id != ElixirBot.owner_id do
          Api.create_message(msg.channel_id, "This command is reserved for the bot owner!")
        else
          code = String.replace_prefix(msg.content, ElixirBot.prefix <> "eval ", "")
          {return, _} = Code.eval_string(code, [], __ENV__)
          Api.create_message(msg.channel_id, "#{inspect return}")
        end
        {:ok, state}
    end

    @doc """
    Bot owner only. Logout of the bot
    """
    def logout(msg, [], state) do
      if msg.author.id != ElixirBot.owner_id do
        Api.create_message(msg.channel_id, "This command is reserved for the bot owner!")
      else
        ElixirBot.logout(GenServer.call(Subscriptions, :get_state))
      end
      System.halt()
      {:ok, state}
    end
end
