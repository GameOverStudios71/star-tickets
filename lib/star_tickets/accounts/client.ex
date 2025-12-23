defmodule StarTickets.Accounts.Client do
  use Ecto.Schema
  import Ecto.Changeset

  schema "clients" do
    field(:name, :string)
    field(:slug, :string)

    has_many(:establishments, StarTickets.Accounts.Establishment)
    has_many(:users, StarTickets.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(client, attrs) do
    client
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name])
    |> generate_slug()
    |> unique_constraint(:slug)
  end

  defp generate_slug(changeset) do
    case get_change(changeset, :name) do
      nil ->
        changeset

      name ->
        slug =
          name
          |> String.downcase()
          |> String.normalize(:nfd)
          |> String.replace(~r/[^a-z0-9\s]/, "")
          |> String.replace(~r/\s+/, "")

        put_change(changeset, :slug, slug)
    end
  end
end
