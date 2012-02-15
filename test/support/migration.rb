class CreateModels < ActiveRecord::Migration
  def self.up
    create_table :mixins do |t|
      t.column :type, :string
      t.column :pos, :integer
      t.column :parent_id, :integer
      t.column :parent_type, :string
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
    end

    create_table :media_files do |t|
      t.column :name, :string
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
    end

    create_table :playlist_media_files do |t|
      t.column :playlist_id, :integer
      t.column :media_file_id, :integer
      t.column :position, :integer
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
    end

    create_table :playlists do |t|
      t.column :name, :string
      t.column :file_count, :integer
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
    end
  end

  def self.down
    drop_table :playlists
    drop_table :playlist_media_files
    drop_table :media_files
    drop_table :mixins
  end
end
