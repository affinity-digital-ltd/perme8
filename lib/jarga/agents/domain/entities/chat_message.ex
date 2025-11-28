defmodule Jarga.Agents.Domain.Entities.ChatMessage do
  @moduledoc """
  Pure domain entity for chat messages.

  This is a value object representing a chat message in the business domain.
  It contains no infrastructure dependencies (no Ecto, no database concerns).

  For database persistence, see Jarga.Agents.Infrastructure.Schemas.ChatMessageSchema.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          chat_session_id: String.t(),
          role: String.t(),
          content: String.t(),
          context_chunks: list(String.t()),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :chat_session_id,
    :role,
    :content,
    :inserted_at,
    :updated_at,
    context_chunks: []
  ]

  @doc """
  Creates a new ChatMessage domain entity from attributes.
  """
  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Converts an infrastructure schema to a domain entity.
  """
  def from_schema(%{__struct__: _} = schema) do
    %__MODULE__{
      id: schema.id,
      chat_session_id: schema.chat_session_id,
      role: schema.role,
      content: schema.content,
      context_chunks: schema.context_chunks || [],
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end
end
