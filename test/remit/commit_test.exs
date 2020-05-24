defmodule Remit.CommitTest do
  use ExUnit.Case
  alias Remit.Commit

  test "message_summary extracts the first line of the message" do
    assert Commit.message_summary(%Commit{message: "My summary\nMore info"}) == "My summary"
    assert Commit.message_summary(%Commit{message: "My summary\rMore info"}) == "My summary"
    assert Commit.message_summary(%Commit{message: "My summary\r\nMore info"}) == "My summary"
  end
end
