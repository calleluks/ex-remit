defmodule RemitWeb.CommitsLive do
  use RemitWeb, :live_view
  alias Remit.{Repo,Commit,Settings}

  # Fairly arbitrary number. If too low, we may miss unreviewed stuff. If too high, performance may suffer.
  @commits_count 200

  # We subscribe on mount, and then when one client updates state, it broadcasts the new state to other clients.
  # Read more: https://elixirschool.com/blog/live-view-with-pub-sub/
  @broadcast_topic "commits"

  @impl true
  def mount(_params, session, socket) do
    settings = Settings.for_session(session)
    commits = Commit.load_latest(@commits_count)

    if connected?(socket) do
      Settings.subscribe_to_changed_settings(settings)
      Commit.subscribe_to_changed_commits()
    end

    socket = socket
      |> assign(settings: settings, your_last_clicked_commit_id: nil)
      |> assign_commits_and_stats(commits)

    {:ok, socket}
  end

  @impl true
  def handle_event("clicked", %{"cid" => commit_id}, socket) do
    socket = assign_clicked_commit_id(socket, commit_id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("start_review", %{"cid" => commit_id}, socket) do
    commit = Commit.mark_as_review_started!(commit_id)

    {:noreply, assign_and_broadcast_changed_commit(socket, commit)}
  end

  @impl true
  def handle_event("mark_reviewed", %{"cid" => commit_id}, socket) do
    commit = Commit.mark_as_reviewed!(commit_id)

    {:noreply, assign_and_broadcast_changed_commit(socket, commit)}
  end

  @impl true
  def handle_event("mark_unreviewed", %{"cid" => commit_id}, socket) do
    commit = Commit.mark_as_unreviewed!(commit_id)

    {:noreply, assign_and_broadcast_changed_commit(socket, commit)}
  end

  # Receive broadcasts when other clients update their state.
  @impl true
  def handle_info({:changed_commit, commit}, socket) do
    commits = socket.assigns.commits |> replace_commit(commit)
    socket = socket |> assign_commits_and_stats(commits)

    {:noreply, socket}
  end

  # Receive broadcasts when other LiveViews update settings.
  @impl true
  def handle_info({:changed_settings, settings}, socket) do
    # We need to update the commit stats because they're based on settings.
    socket = socket
      |> assign(settings: settings)
      |> assign_commits_and_stats(socket.assigns.commits)

    {:noreply, socket}
  end

  # Private

  defp assign_and_broadcast_changed_commit(socket, commit) do
    commit = commit |> Repo.preload(:author)
    commits = socket.assigns.commits |> replace_commit(commit)

    Commit.broadcast_changed_commit(commit)

    socket
      |> assign_commits_and_stats(commits)
      |> assign_clicked_commit_id(commit.id)
  end

  defp assign_clicked_commit_id(socket, commit_id) when is_integer(commit_id), do: assign(socket, your_last_clicked_commit_id: commit_id)
  defp assign_clicked_commit_id(socket, commit_id) when is_binary(commit_id), do: assign_clicked_commit_id(socket, String.to_integer(commit_id))

  defp assign_commits_and_stats(socket, commits) do
    unreviewed_count = commits |> Enum.count(& !&1.reviewed_at)
    my_unreviewed_count = commits |> Enum.count(& !&1.reviewed_at && authored?(socket, &1))
    oldest_unreviewed_for_me = commits |> Enum.reverse() |> Enum.find(& !&1.reviewed_at && !authored?(socket, &1))

    assign(socket, %{
      commits: commits,
      unreviewed_count: unreviewed_count,
      my_unreviewed_count: my_unreviewed_count,
      others_unreviewed_count: unreviewed_count - my_unreviewed_count,
      oldest_unreviewed_for_me: oldest_unreviewed_for_me,
    })
  end

  defp replace_commit(commits, commit) do
    commits |> Enum.map(& if(&1.id == commit.id, do: commit, else: &1))
  end

  defp authored?(socket, commit), do: Settings.authored?(socket.assigns.settings, commit)
end
