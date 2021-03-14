defmodule Dqs.Consumer do
  use Nostrum.Consumer

  alias Dqs.Command
  alias Nostrum.Api
  @prefix System.get_env("PREFIX")
  @question_channel_id String.to_integer(System.get_env("QUESTION_CHANNEL_ID"))

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def handle_event({:MESSAGE_CREATE, %{author: %{bot: nil}, content: @prefix <> _command} = msg, _ws_state}) do
    Command.handle(msg)
  end

  def handle_event({:MESSAGE_CREATE, %{author: %{bot: nil}, channel_id: @question_channel_id} = msg, _ws_state}) do
    Dqs.Command.Create.handle_message(msg)
  end

  def handle_event({:READY, _, ws}) do
    Api.update_shard_status(ws.shard_pid, "dnd", "!help", 0)
  end

  def handle_event(_event) do
    :noop
  end
end
