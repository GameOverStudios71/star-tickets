defmodule StarTickets.Accounts.TV do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "tvs" do
    field(:name, :string)
    field(:news_enabled, :boolean, default: false)
    field(:news_url, :string)
    field(:all_services, :boolean, default: false)
    field(:all_rooms, :boolean, default: false)

    belongs_to(:establishment, StarTickets.Accounts.Establishment)
    belongs_to(:user, StarTickets.Accounts.User)

    many_to_many(:services, StarTickets.Accounts.Service,
      join_through: "tv_services",
      on_replace: :delete
    )

    many_to_many(:rooms, StarTickets.Accounts.Room,
      join_through: "tv_rooms",
      on_replace: :delete
    )

    timestamps()
  end

  @doc false
  def changeset(tv, attrs) do
    tv
    |> cast(attrs, [
      :name,
      :news_enabled,
      :news_url,
      :establishment_id,
      :user_id,
      :all_services,
      :all_rooms
    ])
    |> validate_required([:name, :establishment_id, :user_id])
    |> validate_news()
  end

  defp validate_news(changeset) do
    if get_field(changeset, :news_enabled) do
      validate_required(changeset, [:news_url])
    else
      changeset
    end
  end
end
