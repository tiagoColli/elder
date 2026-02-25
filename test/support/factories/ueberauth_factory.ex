defmodule Elder.UeberauthFactory do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      def ueberauth_auth_factory do
        %Ueberauth.Auth{
          uid: sequence(:uid, &"google_uid_#{&1}"),
          provider: :google,
          info: %Ueberauth.Auth.Info{
            email: sequence(:email, &"user#{&1}@example.com"),
            name: sequence(:name, &"User #{&1}"),
            image: "https://example.com/avatar.png"
          },
          credentials: %Ueberauth.Auth.Credentials{},
          extra: %Ueberauth.Auth.Extra{}
        }
      end
    end
  end
end
