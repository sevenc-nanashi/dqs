defmodule Dqs.Command.Merge do
  alias Dqs.Repo
  import Ecto.Query
  import Nostrum.Struct.Embed

  @prefix Application.get_env(:dqs, :prefix)

  def handle(%{content: @prefix <> "merge " <> merge_id} = message) do
    merge_id = merge_id |> String.replace_prefix("#", "") |> String.to_integer()
    question = get_question_from_id(merge_id)
    if question.status != "closed" do
      Nostrum.Api.create_message(message.channel_id, "質問が閉じられていません。")
    else
      with {:ok, _message} <- edit_close_message(message, question),
           {:ok, _message} <- edit_embed(message, question)
      do
        {:ok, _success_message} = Nostrum.Api.create_message(message.channel_id, "引き継ぎました。")
      else
        err ->
          Nostrum.Api.create_message(message.channel_id, "なんらかの理由で引き継げませんでした。再度お試しください。")
          IO.inspect err
      end
    end
  end

  def handle(_msg), do: :noop

  def get_jump_url(message) do
    "https://discord.com/channels/#{message.guild_id}/#{message.channel_id}/#{message.id}"
  end

  def get_current_question(channel_id) do
    from(
      question in Dqs.Question,
      where: question.channel_id == ^channel_id and question.status == "open",
      preload: [:info],
      select: question
    )
    |> Repo.one()
  end

  def get_question_from_id(question_id) do
    from(
      question in Dqs.Question,
      where: question.id == ^question_id,
      preload: [:info],
      select: question
    )
    |> Repo.one()
  end

  defp edit_close_message(message, target_question) do
    question = get_current_question(message.channel_id)
    Nostrum.Api.edit_message(target_question.channel_id, target_question.close_message_id,
      content: "##{question.id} に引き継がれました。\n#{get_jump_url(message)}"
    )
  end

  defp edit_embed(message, question) do
    question = get_question_from_id(question.id)
    current_question = get_current_question(message.channel_id)
    {:ok, original_message} = Nostrum.Api.get_channel_message(current_question.channel_id, current_question.info.original_message_id)
    IO.puts 2
    [original_embed | _] = original_message.embeds
    embed = original_embed
            |> put_title("引き継がれた質問: " <> question.name)
            |> put_field(
              "引き継ぎ元",
              "[##{question.id}](https://discord.com/channels/#{message.guild_id}/#{question.channel_id}/#{question.info.original_message_id})"
            )
    IO.puts 3
    Nostrum.Api.edit_message(current_question.channel_id, current_question.info.original_message_id, embed: embed)
  end
end
