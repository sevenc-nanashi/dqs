defmodule Dqs.Command.Modify do
  alias Dqs.Repo
  import Ecto.Query

  alias Dqs.Cache

  @prefix System.get_env("PREFIX")
  @board_channel_id System.get_env("QUESTION_BOARD_CHANNEL_ID")
                    |> String.to_integer

  def handle(%{content: @prefix <> "set title " <> title} = msg) do
    set_title(msg, title)
  end

  def handle(%{content: @prefix <> "set content"} = msg) do
    case msg.referenced_message do
      nil -> Nostrum.Api.create_message(msg.channel_id, "リプライ元が存在しません。")
      referenced_message -> set_content(msg, referenced_message.content)
    end
  end

  def handle(%{content: @prefix <> "set content " <> content} = msg) do
    set_content(msg, content)
  end

  def set_title(msg, title) do
    channel_id = msg.channel_id
    question =
      from(
        question in Dqs.Question,
        where: question.channel_id == ^channel_id,
        preload: [:info],
        select: question
      )
      |> Repo.one()
      |> Ecto.Changeset.change(name: title)
    with {:ok, question} <- do_update(question),
         {:ok, _channel} <- update_channel_name(msg, question),
         {:ok, _message} <- update_info_message(question)
      do
      send_message(msg, "変更しました。")
    else
      _ -> send_message(msg, "アップデートができませんでした。再度お試しください。")
    end
  end

  def send_message(msg, content) do
    Nostrum.Api.create_message(msg.channel_id, content)
  end

  def update_channel_name(msg, question) do
    Nostrum.Api.modify_channel(msg.channel_id, name: question.name)
  end

  def update_info_message(question) do
    info = question.info
    {:ok, user} = Cache.get_user(question.issuer_id)
    Nostrum.Api.edit_message(
      @board_channel_id,
      info.info_message_id,
      embed: Dqs.Embed.make_info_embed(user, question, question.info)
    )
  end

  def set_content(msg, content) do
    channel_id = msg.channel_id
    question =
      from(
        question in Dqs.Question,
        where: question.channel_id == ^channel_id,
        preload: [:info],
        select: question
      )
      |> Repo.one()
      |> Ecto.Changeset.change(content: content)
    with {:ok, question} <- do_update(question),
         {:ok, _message} <- update_info_message(question)
      do
      send_message(msg, "変更しました。")
    else
      _error -> send_message(msg, "アップデートができませんでした。再度お試しください。")
    end
  end

  def do_update(question) do
    case Repo.update question do
      {:ok, question} -> {:ok, question}
      {:error, _} -> {:error, :update}
    end
  end
end