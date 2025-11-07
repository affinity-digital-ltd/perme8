defmodule Jarga.Accounts.UserNotifier do
  @moduledoc """
  Delivers email notifications for user account actions.
  """

  import Swoosh.Email

  alias Jarga.Mailer
  alias Jarga.Accounts.User

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body, opts) do
    from_email = System.get_env("SENDGRID_FROM_EMAIL", "noreply@jarga.app")
    from_name = System.get_env("SENDGRID_FROM_NAME", "Jarga")

    email =
      new()
      |> to(recipient)
      |> from({from_name, from_email})
      |> subject(subject)
      |> text_body(body)
      |> maybe_disable_tracking(opts)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  # Disables SendGrid click tracking for authentication emails
  # This ensures magic links and confirmation links work correctly
  defp maybe_disable_tracking(email, opts) do
    if Keyword.get(opts, :disable_tracking, false) do
      email
      |> put_provider_option(:click_tracking, %{enable: false})
      |> put_provider_option(:open_tracking, %{enable: false})
    else
      email
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(
      user.email,
      "Update email instructions",
      """

      ==============================

      Hi #{user.email},

      You can change your email by visiting the URL below:

      #{url}

      If you didn't request this change, please ignore this.

      ==============================
      """,
      disable_tracking: true
    )
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(
      user.email,
      "Log in instructions",
      """

      ==============================

      Hi #{user.email},

      You can log into your account by visiting the URL below:

      #{url}

      If you didn't request this email, please ignore this.

      ==============================
      """,
      disable_tracking: true
    )
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(
      user.email,
      "Confirmation instructions",
      """

      ==============================

      Hi #{user.email},

      You can confirm your account by visiting the URL below:

      #{url}

      If you didn't create an account with us, please ignore this.

      ==============================
      """,
      disable_tracking: true
    )
  end
end
