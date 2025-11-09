defmodule JargaWeb.ChatLive.Components.Message do
  @moduledoc """
  Message component for displaying chat messages.
  """
  use Phoenix.Component

  attr :message, :map, required: true
  attr :show_insert, :boolean, default: false
  attr :panel_target, :any, default: nil

  def message(assigns) do
    ~H"""
    <div class={"chat #{if @message.role == "user", do: "chat-end", else: "chat-start"}"}>
      <%= if !Map.get(@message, :streaming, false) do %>
        <div class="chat-header opacity-50 text-xs">
          {format_timestamp(@message.timestamp)}
        </div>
      <% end %>

      <div class={"chat-bubble #{if @message.role == "user", do: "chat-bubble-primary", else: ""}"}>
        {@message.content}
        <%= if Map.get(@message, :streaming, false) do %>
          <span class="inline-block w-2 h-4 bg-current opacity-75 animate-pulse ml-1">▊</span>
        <% end %>
      </div>

      <%= if should_show_insert_link?(assigns) do %>
        <div class="chat-footer text-xs opacity-70">
          <span
            phx-click="insert_into_note"
            phx-target={@panel_target}
            phx-value-content={@message.content}
            class="link link-info cursor-pointer"
            role="button"
            tabindex="0"
            title="Insert this text into the current note"
          >
            insert
          </span>
        </div>
      <% end %>
    </div>
    """
  end

  # Only show insert link for assistant messages that aren't streaming
  defp should_show_insert_link?(assigns) do
    assigns[:show_insert] == true &&
      assigns.message.role == "assistant" &&
      !Map.get(assigns.message, :streaming, false)
  end

  defp format_timestamp(timestamp) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, timestamp, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86_400 -> "#{div(diff_seconds, 3600)}h ago"
      true -> Calendar.strftime(timestamp, "%b %d, %I:%M %p")
    end
  end
end
