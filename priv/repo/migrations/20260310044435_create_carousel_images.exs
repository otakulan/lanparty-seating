defmodule Lanpartyseating.Repo.Migrations.CreateCarouselImages do
  use Ecto.Migration

  def change do
    create table(:carousel_images) do
      add :title, :string, size: 255
      add :image_data, :binary, null: false
      add :content_type, :string, size: 64, null: false
      add :display_order, :integer, null: false, default: 0
      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:carousel_images, [:display_order])
  end
end
