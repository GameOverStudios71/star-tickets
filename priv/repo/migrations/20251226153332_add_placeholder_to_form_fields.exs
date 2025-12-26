defmodule StarTickets.Repo.Migrations.AddPlaceholderToFormFields do
  use Ecto.Migration

  def change do
    alter table(:form_fields) do
      add(:placeholder, :string)
    end
  end
end
