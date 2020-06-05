defmodule Remit.Commit do
  use Ecto.Schema
  import Ecto.Query
  alias Remit.{Commit, Repo}

  @timestamps_opts [type: :utc_datetime]

  schema "commits" do
    field :sha, :string
    field :author_email, :string
    field :author_name, :string
    field :author_usernames, {:array, :string}
    field :owner, :string
    field :repo, :string
    field :message, :string
    field :committed_at, :utc_datetime
    field :url, :string

    field :review_started_at, :utc_datetime
    field :reviewed_at, :utc_datetime
    field :review_started_by_email, :string
    field :reviewed_by_email, :string

    timestamps()
  end

  def load_latest(count) do
    Repo.all(from Commit, limit: ^count, order_by: [desc: :id])
  end

  def shas(limit: limit) do
    Repo.all(from Commit, select: [:sha], order_by: [desc: :id], limit: ^limit) |> Enum.map(& &1.sha)
  end

  def mark_as_reviewed!(id, reviewer_email) when is_binary(reviewer_email) do
    update!(id, reviewed_at: now(), reviewed_by_email: reviewer_email)
  end

  def mark_as_unreviewed!(id) do
    update!(id, reviewed_at: nil, review_started_at: nil, reviewed_by_email: nil, review_started_by_email: nil)
  end

  def mark_as_review_started!(id, reviewer_email) when is_binary(reviewer_email) do
    update!(id, review_started_at: now(), review_started_by_email: reviewer_email)
  end

  def authored_by?(_commit, nil), do: false
  def authored_by?(commit, username), do: Enum.member?(commit.author_usernames, username)

  def being_reviewed_by?(%Commit{review_started_by_email: email}, email) when not is_nil(email), do: true
  def being_reviewed_by?(_, _), do: false

  def message_summary(commit), do: commit.message |> String.split(~r/\R/) |> hd

  def subscribe, do: Phoenix.PubSub.subscribe(Remit.PubSub, "commits")

  def broadcast_changed_commit(commit) do
    Phoenix.PubSub.broadcast_from!(Remit.PubSub, self(), "commits", {:changed_commit, commit})
  end

  def broadcast_new_commits([]), do: nil  # No-op.
  def broadcast_new_commits(commits) do
    Phoenix.PubSub.broadcast_from!(Remit.PubSub, self(), "commits", {:new_commits, commits})
  end

  # Private

  defp update!(id, attributes) do
    Repo.get_by(Commit, id: id)
    |> Ecto.Changeset.change(attributes)
    |> Repo.update!()
  end

  # TODO: Allow useconds in DB so we don't need this dance.
  defp now(), do: DateTime.utc_now() |> DateTime.truncate(:second)
end
