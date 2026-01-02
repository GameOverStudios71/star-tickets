defmodule StarTickets.Audit.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "audit_logs" do
    field :action, :string
    field :resource_type, :string
    field :resource_id, :string
    field :details, :map
    field :metadata, :map

    belongs_to :user, StarTickets.Accounts.User

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [:user_id, :action, :resource_type, :resource_id, :details, :metadata])
    |> validate_required([:action])
  end
end
