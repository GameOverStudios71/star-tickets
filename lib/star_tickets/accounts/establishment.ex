defmodule StarTickets.Accounts.Establishment do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :code,
             :address,
             :phone,
             :is_active,
             :client_id,
             :inserted_at,
             :updated_at
           ]}
  schema "establishments" do
    field(:name, :string)
    field(:code, :string)
    field(:address, :string)
    field(:phone, :string)
    field(:is_active, :boolean, default: true)

    belongs_to(:client, StarTickets.Accounts.Client)
    has_many(:users, StarTickets.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(establishment, attrs) do
    establishment
    |> cast(attrs, [:name, :code, :address, :phone, :is_active, :client_id])
    |> validate_required([:name, :code, :client_id])
    |> generate_code()
    |> foreign_key_constraint(:client_id)
    |> unique_constraint(:code, name: "establishments_client_id_code_index")
    |> unique_constraint(:name,
      name: "establishments_client_id_name_index",
      message: "já existe um estabelecimento com este nome"
    )
  end

  defp generate_code(changeset) do
    case {get_change(changeset, :code), get_change(changeset, :name)} do
      {nil, name} when is_binary(name) ->
        code =
          name
          |> String.upcase()
          |> String.normalize(:nfd)
          |> String.replace(~r/[^A-Z0-9\s]/, "")
          |> String.replace(~r/\s+/, "_")
          |> String.slice(0, 20)

        put_change(changeset, :code, code)

      _ ->
        changeset
    end
  end
end
