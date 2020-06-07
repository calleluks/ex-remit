defmodule Remit.IngestCommitsTest do
  use Remit.DataCase
  import Ecto.Query
  alias Remit.{IngestCommits, Repo, Commit}

  # Also see GithubWebhookControllerTest.

  test "creates commits" do
    build_params(sha: "abc123") |> IngestCommits.from_params()

    assert Repo.exists?(from Commit, where: [sha: "abc123"])
  end

  test "assigns usernames from author username and committer username" do
    [commit] = build_params(author_username: "foo", committer_username: "bar") |> IngestCommits.from_params()
    assert commit.usernames == ["foo", "bar"]

    [commit] = build_params(author_username: "foo", committer_username: nil) |> IngestCommits.from_params()
    assert commit.usernames == ["foo"]

    [commit] = build_params(author_username: nil, committer_username: "bar") |> IngestCommits.from_params()
    assert commit.usernames == ["bar"]

    [commit] = build_params(author_username: "foo", committer_username: "foo") |> IngestCommits.from_params()
    assert commit.usernames == ["foo"]
  end

  test "assigns usernames from author and committer email 'plus addressing'" do
    [commit] = build_params(
      author_username: nil,
      author_email: "devs+foo+bar@example.com",
      committer_username: nil,
      committer_email: "devs+baz+boink@auctionet.com"
    ) |> IngestCommits.from_params()
    assert commit.usernames == ["foo", "bar", "baz", "boink"]
  end

  test "can mix usernames and 'plus addressing'" do
    [commit] = build_params(
      author_username: nil,
      author_email: "devs+foo+bar@example.com",
      committer_username: "baz"
    ) |> IngestCommits.from_params()
    assert commit.usernames == ["foo", "bar", "baz"]
  end

  # Private

  defp build_params(opts) do
    branch = Keyword.get(opts, :branch, "master")
    sha = Keyword.get(opts, :sha, Faker.sha())
    author_username = Keyword.get(opts, :author_username, "foobarson")
    committer_username = Keyword.get(opts, :committer_username, "foobarson")
    author_email = Keyword.get(opts, :author_email, "foo@example.com")
    committer_email = Keyword.get(opts, :committer_email, "foo@example.com")

    author = %{
      "email" => author_email,
      "name" => "Foo Barson",
    }
    author = if author_username, do: Map.merge(author, %{"username" => author_username}), else: author

    committer = %{
      "email" => committer_email,
      "name" => "Foo Barson",
    }
    committer = if committer_username, do: Map.merge(committer, %{"username" => committer_username}), else: committer

    %{
      "ref" => "refs/heads/#{branch}",
      "repository" => %{
        "master_branch" => "master",
        "name" => "myrepo",
        "owner" => %{
          "name" => "acme",
        },
      },
      "commits" => [
        %{
          "author" => author,
          "committer" => committer,
          "id" => sha,
          "url" => "http://example.com/1",
          "message" => "Commit",
          "timestamp" => "2016-01-25T08:41:25+01:00",
        },
      ],
    }
  end
end