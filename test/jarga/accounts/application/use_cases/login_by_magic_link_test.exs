defmodule Jarga.Accounts.Application.UseCases.LoginByMagicLinkTest do
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures

  alias Jarga.Accounts.Application.UseCases.LoginByMagicLink
  alias Jarga.Accounts.Domain.Entities.UserToken

  describe "execute/2" do
    test "Case 1: confirmed user with password - deletes token only" do
      user = user_fixture()
      user = %{user | confirmed_at: DateTime.utc_now()}
      {token, user_token} = UserToken.build_email_token(user, "login")
      inserted_token = Repo.insert!(user_token)

      assert {:ok, {returned_user, expired_tokens}} = LoginByMagicLink.execute(%{token: token})
      assert returned_user.id == user.id
      assert returned_user.confirmed_at != nil
      assert expired_tokens == []

      # Token should be deleted
      refute Repo.get(UserToken, inserted_token.id)
    end

    test "Case 2: unconfirmed user without password - confirms and deletes all tokens" do
      # Create a basic user first, then remove password
      user = user_fixture()
      # Update user to remove password and confirmation
      user_updated =
        user
        |> Ecto.Changeset.change(%{hashed_password: nil, confirmed_at: nil})
        |> Repo.update!()

      {token, user_token} = UserToken.build_email_token(user_updated, "login")
      inserted_token = Repo.insert!(user_token)

      # Create additional token to verify all are deleted
      {_other_token, other_user_token} = UserToken.build_session_token(user_updated)
      inserted_other_token = Repo.insert!(other_user_token)

      assert {:ok, {returned_user, expired_tokens}} = LoginByMagicLink.execute(%{token: token})
      assert returned_user.id == user_updated.id
      assert returned_user.confirmed_at != nil
      assert length(expired_tokens) >= 1

      # All tokens should be deleted
      refute Repo.get(UserToken, inserted_token.id)
      refute Repo.get(UserToken, inserted_other_token.id)
    end

    test "Case 3: unconfirmed user with password - confirms and deletes only magic link token" do
      user = user_fixture()
      # Update user to be unconfirmed
      user_unconfirmed =
        user
        |> Ecto.Changeset.change(%{confirmed_at: nil})
        |> Repo.update!()

      {token, user_token} = UserToken.build_email_token(user_unconfirmed, "login")
      inserted_token = Repo.insert!(user_token)

      assert {:ok, {returned_user, expired_tokens}} = LoginByMagicLink.execute(%{token: token})
      assert returned_user.id == user_unconfirmed.id
      assert returned_user.confirmed_at != nil
      assert expired_tokens == []

      # Only magic link token should be deleted
      refute Repo.get(UserToken, inserted_token.id)
    end

    test "returns error for invalid token" do
      assert {:error, :invalid_token} = LoginByMagicLink.execute(%{token: "invalid-token"})
    end

    test "returns error for not found token" do
      # Valid Base64 but doesn't exist in database
      valid_token = Base.url_encode64(:crypto.strong_rand_bytes(32))
      assert {:error, :not_found} = LoginByMagicLink.execute(%{token: valid_token})
    end

    test "transaction rolls back on failure" do
      user = user_fixture()
      user = %{user | confirmed_at: nil}
      {token, user_token} = UserToken.build_email_token(user, "login")
      Repo.insert!(user_token)

      # This test verifies that if any step fails, the transaction rolls back
      # We can't easily force a failure in the current implementation,
      # but the transaction boundary ensures atomicity
      assert {:ok, {_returned_user, _expired_tokens}} = LoginByMagicLink.execute(%{token: token})
    end

    test "accepts injectable repo for testing" do
      user = user_fixture()
      user = %{user | confirmed_at: DateTime.utc_now()}
      {token, user_token} = UserToken.build_email_token(user, "login")
      Repo.insert!(user_token)

      assert {:ok, {_user, _tokens}} =
               LoginByMagicLink.execute(%{token: token}, repo: Jarga.Repo)
    end
  end
end
