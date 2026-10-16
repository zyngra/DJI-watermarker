class CreateInspections < ActiveRecord::Migration[8.1]
  def change
    create_table :inspections do |t|
      t.string :title
      t.string :protocol

      t.timestamps
    end
  end
end
