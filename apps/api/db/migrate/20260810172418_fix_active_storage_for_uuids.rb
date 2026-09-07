class FixActiveStorageForUuids < ActiveRecord::Migration[8.1]
  def up
    # Active Storage was installed with bigint record_id, but our models use UUID primary keys.
    # Change record_id to uuid type so polymorphic associations work correctly.
    remove_index :active_storage_attachments, name: "index_active_storage_attachments_uniqueness"
    change_column :active_storage_attachments, :record_id, :uuid, null: false, using: "gen_random_uuid()"
    add_index :active_storage_attachments, [ :record_type, :record_id, :name, :blob_id ],
              name: "index_active_storage_attachments_uniqueness", unique: true
  end

  def down
    remove_index :active_storage_attachments, name: "index_active_storage_attachments_uniqueness"
    change_column :active_storage_attachments, :record_id, :bigint, null: false
    add_index :active_storage_attachments, [ :record_type, :record_id, :name, :blob_id ],
              name: "index_active_storage_attachments_uniqueness", unique: true
  end
end
