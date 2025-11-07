# Test script to verify notification PubSub is working
# Run with: mix run test_notification_pubsub.exs

# Start the application
{:ok, _} = Application.ensure_all_started(:jarga)

# Import Ecto.Query for from/2
import Ecto.Query

# Get a test user
user = Jarga.Repo.one!(from(u in Jarga.Accounts.User, limit: 1))

IO.puts("Testing PubSub for user: #{user.email} (ID: #{user.id})")

# Subscribe to the notification channel
Phoenix.PubSub.subscribe(Jarga.PubSub, "user:#{user.id}:notifications")
IO.puts("Subscribed to: user:#{user.id}:notifications")

# Create a test notification
notification_attrs = %{
  user_id: user.id,
  type: "workspace_invitation",
  title: "Test Notification",
  body: "This is a test",
  data: %{"workspace_id" => Ecto.UUID.generate()}
}

{:ok, notification} =
  Jarga.Notifications.Infrastructure.NotificationRepository.create(notification_attrs)

IO.puts("Created notification: #{notification.id}")

# Broadcast it
Phoenix.PubSub.broadcast(
  Jarga.PubSub,
  "user:#{user.id}:notifications",
  {:new_notification, notification}
)

IO.puts("Broadcasted notification")

# Wait for message
receive do
  {:new_notification, received_notification} ->
    IO.puts("✓ Received notification: #{received_notification.id}")
    IO.puts("PubSub is working correctly!")
after
  1000 ->
    IO.puts("✗ Did not receive notification within 1 second")
    IO.puts("PubSub may not be working correctly")
end
