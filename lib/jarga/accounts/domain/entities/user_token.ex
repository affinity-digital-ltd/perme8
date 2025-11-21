defmodule Jarga.Accounts.Domain.Entities.UserToken do
  @moduledoc """
  Schema for user authentication tokens used for sessions, magic links, and email changes.

  This is a pure Ecto schema with NO business logic.
  Token building logic has been moved to TokenBuilder domain service.

  ## Note

  The `build_session_token/1` and `build_email_token/2` functions are kept here
  for backward compatibility and delegate to TokenBuilder service.
  """

  use Ecto.Schema
  alias Jarga.Accounts.Domain.Services.TokenBuilder

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users_tokens" do
    field(:token, :binary)
    field(:context, :string)
    field(:sent_to, :string)
    field(:authenticated_at, :utc_datetime)
    belongs_to(:user, Jarga.Accounts.Domain.Entities.User, type: :binary_id)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Generates a token that will be stored in a signed place,
  such as session or cookie. As they are signed, those
  tokens do not need to be hashed.

  The reason why we store session tokens in the database, even
  though Phoenix already provides a session cookie, is because
  Phoenix' default session cookies are not persisted, they are
  simply signed and potentially encrypted. This means they are
  valid indefinitely, unless you change the signing/encryption
  salt.

  Therefore, storing them allows individual user
  sessions to be expired. The token system can also be extended
  to store additional data, such as the device used for logging in.
  You could then use this information to display all valid sessions
  and devices in the UI and allow users to explicitly expire any
  session they deem invalid.
  """
  def build_session_token(user) do
    TokenBuilder.build_session_token(user)
  end

  @doc """
  Builds a token and its hash to be delivered to the user's email.

  The non-hashed token is sent to the user email while the
  hashed part is stored in the database. The original token cannot be reconstructed,
  which means anyone with read-only access to the database cannot directly use
  the token in the application to gain access. Furthermore, if the user changes
  their email in the system, the tokens sent to the previous email are no longer
  valid.

  Users can easily adapt the existing code to provide other types of delivery methods,
  for example, by phone numbers.
  """
  def build_email_token(user, context) do
    TokenBuilder.build_email_token(user, context)
  end
end
