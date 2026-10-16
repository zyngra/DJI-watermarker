class CreatePhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :photos do |t|
      t.references :inspection, null: false, foreign_key: true
      t.string :filename
      t.datetime :captured_at
      t.float :latitude
      t.float :longitude
      t.float :relative_altitude
      t.float :absolute_altitude
      t.float :gimbal_yaw
      t.float :gimbal_pitch
      t.float :fov_deg

      t.timestamps
    end
  end
end
