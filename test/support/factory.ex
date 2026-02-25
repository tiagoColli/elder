defmodule Elder.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Elder.Repo
  use Elder.UserFactory
  use Elder.UeberauthFactory
end
