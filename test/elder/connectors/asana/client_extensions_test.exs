defmodule Elder.Asana.ClientExtensionsTest do
  use ExUnit.Case, async: false

  import Mox

  alias Elder.Asana.ClientMock

  setup :verify_on_exit!

  describe "update_task/2 via mock" do
    test "returns {:ok, %{task_gid: _}} on success" do
      expect(ClientMock, :update_task, fn "task-123", %{"assignee" => "dev@co.com"} ->
        {:ok, %{task_gid: "task-123"}}
      end)

      assert {:ok, %{task_gid: "task-123"}} =
               ClientMock.update_task("task-123", %{"assignee" => "dev@co.com"})
    end

    test "returns {:error, _} on failure" do
      expect(ClientMock, :update_task, fn _gid, _fields ->
        {:error, {:asana_api_error, 400, %{"errors" => []}}}
      end)

      assert {:error, {:asana_api_error, 400, _body}} =
               ClientMock.update_task("task-123", %{"assignee" => "bad"})
    end
  end

  describe "add_tag_to_task/2 via mock" do
    test "returns :ok on success" do
      expect(ClientMock, :add_tag_to_task, fn "task-123", "tag-456" -> :ok end)

      assert :ok = ClientMock.add_tag_to_task("task-123", "tag-456")
    end

    test "returns {:error, _} on failure" do
      expect(ClientMock, :add_tag_to_task, fn _gid, _tag ->
        {:error, {:asana_api_error, 404, %{"errors" => []}}}
      end)

      assert {:error, {:asana_api_error, 404, _body}} =
               ClientMock.add_tag_to_task("task-123", "bad-tag")
    end
  end
end
