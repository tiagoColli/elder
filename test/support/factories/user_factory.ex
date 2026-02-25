defmodule Elder.UserFactory do
  @moduledoc false

  alias Elder.Accounts.Schemas.User

  defmacro __using__(_opts) do
    quote do
      def user_factory do
        %User{
          email: sequence(:email, &"user#{&1}@example.com"),
          name: sequence(:name, &"User #{&1}"),
          avatar_url: "https://example.com/avatar.png",
          google_uid: sequence(:google_uid, &"google_uid_#{&1}")
        }
      end
    end
  end
end
