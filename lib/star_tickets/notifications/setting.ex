defmodule StarTickets.Notifications.Setting do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias StarTickets.Repo

  schema "notification_settings" do
    field :notification_type, :string
    field :role, :string
    field :whatsapp_enabled, :boolean, default: true
    field :inbox_enabled, :boolean, default: true

    timestamps()
  end

  @doc false
  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:notification_type, :role, :whatsapp_enabled, :inbox_enabled])
    |> validate_required([:notification_type, :role])
    |> unique_constraint([:notification_type, :role])
  end

  # --- Context Functions ---

  def list_settings do
    Repo.all(from s in __MODULE__, order_by: [s.notification_type, s.role])
  end

  def get_setting(type, role) do
    Repo.get_by(__MODULE__, notification_type: type, role: role)
  end

  def update_setting(setting, attrs) do
    setting
    |> changeset(attrs)
    |> Repo.update()
  end

  def create_setting(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  def get_or_create_setting(type, role) do
    case get_setting(type, role) do
      nil ->
        create_setting(%{notification_type: type, role: role})

      setting ->
        {:ok, setting}
    end
  end

  def whatsapp_enabled?(type, role) do
    case get_setting(type, role) do
      # Default to true if not set
      nil -> true
      setting -> setting.whatsapp_enabled
    end
  end
end
