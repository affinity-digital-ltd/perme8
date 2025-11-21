defmodule Jarga.Agents.UseCases.DeleteMessage do
  @moduledoc """
  Deletes a chat message from a session.

  This use case handles removing individual messages from chat sessions,
  verifying ownership through the session's user_id.

  ## Examples

      iex> DeleteMessage.execute(message_id, user_id)
      {:ok, %ChatMessage{}}

      iex> DeleteMessage.execute(invalid_id, user_id)
      {:error, :not_found}
  """

  alias Jarga.Repo
  alias Jarga.Agents.ChatMessage
  alias Jarga.Agents.ChatSession
  import Ecto.Query

  @doc """
  Deletes a message by ID, verifying the user owns the session.

  ## Parameters
    - message_id: ID of the message to delete
    - user_id: ID of the user requesting deletion

  Returns `{:ok, message}` if successful, or `{:error, :not_found}` if not found
  or user doesn't own the session.
  """
  def execute(message_id, user_id) do
    query =
      from(m in ChatMessage,
        join: s in ChatSession,
        on: m.chat_session_id == s.id,
        where: m.id == ^message_id and s.user_id == ^user_id,
        select: m
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      message -> Repo.delete(message)
    end
  end
end
