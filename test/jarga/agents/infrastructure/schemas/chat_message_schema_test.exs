defmodule Jarga.Agents.Infrastructure.Schemas.ChatMessageSchemaTest do
  @moduledoc """
  Tests for ChatMessageSchema.
  """
  use Jarga.DataCase, async: true

  import Jarga.AgentsFixtures

  alias Jarga.Agents.Infrastructure.Schemas.ChatMessageSchema

  describe "changeset/2" do
    test "valid changeset with all required fields" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        role: "user",
        content: "Hello, how can I help?"
      }

      changeset = ChatMessageSchema.changeset(%ChatMessageSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :chat_session_id) == session.id
      assert get_change(changeset, :role) == "user"
      assert get_change(changeset, :content) == "Hello, how can I help?"
    end

    test "valid changeset with assistant role" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        role: "assistant",
        content: "I'm here to help!"
      }

      changeset = ChatMessageSchema.changeset(%ChatMessageSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :role) == "assistant"
    end

    test "valid changeset with context_chunks" do
      session = chat_session_fixture()
      chunk_id1 = Ecto.UUID.generate()
      chunk_id2 = Ecto.UUID.generate()

      attrs = %{
        chat_session_id: session.id,
        role: "assistant",
        content: "Based on the documents...",
        context_chunks: [chunk_id1, chunk_id2]
      }

      changeset = ChatMessageSchema.changeset(%ChatMessageSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :context_chunks) == [chunk_id1, chunk_id2]
    end

    test "invalid without chat_session_id" do
      attrs = %{
        role: "user",
        content: "Hello"
      }

      changeset = ChatMessageSchema.changeset(%ChatMessageSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).chat_session_id
    end

    test "invalid without role" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        content: "Hello"
      }

      changeset = ChatMessageSchema.changeset(%ChatMessageSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).role
    end

    test "invalid without content" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        role: "user"
      }

      changeset = ChatMessageSchema.changeset(%ChatMessageSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).content
    end

    test "invalid with invalid role" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        role: "invalid",
        content: "Hello"
      }

      changeset = ChatMessageSchema.changeset(%ChatMessageSchema{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).role
    end

    test "content is trimmed of whitespace" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        role: "user",
        content: "  Hello World  "
      }

      changeset = ChatMessageSchema.changeset(%ChatMessageSchema{}, attrs)

      assert get_change(changeset, :content) == "Hello World"
    end

    test "empty content after trim is invalid" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        role: "user",
        content: "   "
      }

      changeset = ChatMessageSchema.changeset(%ChatMessageSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).content
    end

    test "context_chunks defaults to empty array" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        role: "user",
        content: "Hello"
      }

      changeset = ChatMessageSchema.changeset(%ChatMessageSchema{}, attrs)

      # Default value is applied at database level, so no change in changeset
      assert get_change(changeset, :context_chunks) == nil
    end

    test "handles non-binary content gracefully" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        role: "user",
        content: 123
      }

      changeset = ChatMessageSchema.changeset(%ChatMessageSchema{}, attrs)

      # Should have validation error for content type
      refute changeset.valid?
    end

    test "handles nil content without changes" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        role: "user"
      }

      changeset = ChatMessageSchema.changeset(%ChatMessageSchema{}, attrs)

      # Nil content should not be modified by trim_content
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).content
    end
  end
end
