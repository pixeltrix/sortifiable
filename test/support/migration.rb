class CreateModels < ActiveRecord::Migration
  def self.up
    create_table :mixins do |t|
      t.column :type, :string
      t.column :pos, :integer
      t.column :parent_id, :integer
      t.column :parent_type, :string
      t.column :deleted_at, :datetime
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
    end
  end

  def self.down
    drop_table :mixins
  end
end
