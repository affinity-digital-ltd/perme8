defmodule JargaWeb.NotificationsLive.NotificationBellTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jarga.Accounts
  alias Jarga.Notifications
  alias Jarga.Workspaces

  setup do
    # Create test users
    {:ok, owner} =
      Accounts.register_user(%{
        email: "owner@example.com",
        password: "ValidPassword123!",
        first_name: "Owner",
        last_name: "User"
      })

    {:ok, invitee} =
      Accounts.register_user(%{
        email: "invitee@example.com",
        password: "ValidPassword123!",
        first_name: "Invitee",
        last_name: "User"
      })

    # Create workspace
    {:ok, workspace} =
      Workspaces.create_workspace(owner, %{
        name: "Test Workspace"
      })

    %{owner: owner, invitee: invitee, workspace: workspace}
  end

  describe "PubSub subscription" do
    test "component receives and handles notifications broadcasted via PubSub", %{
      conn: conn,
      owner: owner,
      invitee: invitee,
      workspace: workspace
    } do
      conn = log_in_user(conn, invitee)

      # Mount a LiveView that contains the notification bell component
      {:ok, view, _html} = live(conn, ~p"/app")

      # Initially should have 0 unread count
      assert element(view, "#notification-bell") |> render() =~ "Notifications"

      # Create a notification (this will broadcast via PubSub)
      {:ok, _notification} =
        Notifications.create_workspace_invitation_notification(%{
          user_id: invitee.id,
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          invited_by_name: owner.email,
          role: "member"
        })

      # The component should update automatically via handle_info
      # Wait a bit for the async update
      :timer.sleep(200)

      # Check that the notification bell component now shows the unread badge
      notification_bell_html = element(view, "#notification-bell") |> render()
      assert notification_bell_html =~ ~r/bg-error.*rounded-full/
    end

    test "receives new notification via PubSub and updates bell", %{
      conn: conn,
      owner: owner,
      invitee: invitee,
      workspace: workspace
    } do
      conn = log_in_user(conn, invitee)

      # Mount the LiveView
      {:ok, view, _html} = live(conn, ~p"/app")

      # Create a notification (this will broadcast via PubSub)
      {:ok, _notification} =
        Notifications.create_workspace_invitation_notification(%{
          user_id: invitee.id,
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          invited_by_name: owner.email,
          role: "member"
        })

      # The component should update automatically via handle_info
      :timer.sleep(200)

      # Check that the bell shows the unread count
      notification_bell_html = element(view, "#notification-bell") |> render()
      assert notification_bell_html =~ ~r/bg-error.*rounded-full/

      # Open the dropdown to see the notification
      view
      |> element("#notification-bell button[aria-label='Notifications']")
      |> render_click()

      # Check the dropdown content
      notification_bell_html = element(view, "#notification-bell") |> render()
      assert notification_bell_html =~ "Test Workspace"
      assert notification_bell_html =~ "invited you to join"
    end

    test "updates unread count when new notification arrives", %{
      conn: conn,
      owner: owner,
      invitee: invitee,
      workspace: workspace
    } do
      conn = log_in_user(conn, invitee)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Send first notification
      {:ok, _notification} =
        Notifications.create_workspace_invitation_notification(%{
          user_id: invitee.id,
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          invited_by_name: owner.email,
          role: "member"
        })

      :timer.sleep(200)
      notification_bell_html = element(view, "#notification-bell") |> render()

      # Should show count of 1
      assert notification_bell_html =~ "1"

      # Send second notification
      {:ok, workspace2} =
        Workspaces.create_workspace(owner, %{
          name: "Another Workspace"
        })

      {:ok, _notification2} =
        Notifications.create_workspace_invitation_notification(%{
          user_id: invitee.id,
          workspace_id: workspace2.id,
          workspace_name: workspace2.name,
          invited_by_name: owner.email,
          role: "admin"
        })

      :timer.sleep(200)
      notification_bell_html = element(view, "#notification-bell") |> render()

      # Should show count of 2
      assert notification_bell_html =~ "2"
    end
  end

  describe "existing functionality" do
    test "shows notifications when dropdown is toggled", %{
      conn: conn,
      invitee: invitee,
      owner: owner,
      workspace: workspace
    } do
      # Create a notification first
      {:ok, _notification} =
        Notifications.create_workspace_invitation_notification(%{
          user_id: invitee.id,
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          invited_by_name: owner.email,
          role: "member"
        })

      conn = log_in_user(conn, invitee)
      {:ok, view, _html} = live(conn, ~p"/app")

      # Click the bell to open dropdown
      view
      |> element("#notification-bell button[aria-label='Notifications']")
      |> render_click()

      html = render(view)

      # Should show the notification
      assert html =~ workspace.name
      assert html =~ "invited you to join"
    end

    test "marks notification as read when clicked", %{
      conn: conn,
      invitee: invitee,
      owner: owner,
      workspace: workspace
    } do
      {:ok, notification} =
        Notifications.create_workspace_invitation_notification(%{
          user_id: invitee.id,
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          invited_by_name: owner.email,
          role: "member"
        })

      conn = log_in_user(conn, invitee)
      {:ok, view, _html} = live(conn, ~p"/app")

      # Open dropdown
      view
      |> element("#notification-bell button[aria-label='Notifications']")
      |> render_click()

      # Click mark as read
      view
      |> element("button[phx-click='mark_read'][phx-value-notification-id='#{notification.id}']")
      |> render_click()

      # Verify notification was marked as read
      updated_notification = Notifications.get_notification(notification.id, invitee.id)
      assert updated_notification.read == true
    end
  end
end
