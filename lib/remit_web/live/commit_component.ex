defmodule RemitWeb.CommitComponent do
  use Phoenix.LiveComponent

  alias Remit.{Commit,Utils}

  defp gravatar(email, class) do
    assigns = %{}

    ~L"""
    <img src="<%= Gravatar.url(email) %>" alt="" title="<%= email %>" class="<%= class %>" />
    """
  end
end
