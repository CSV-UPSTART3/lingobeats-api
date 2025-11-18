# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:vocabularies) do
      primary_key :id
      String   :name,   null: false
      String   :level,     null: false
      Text     :material,   null: false # 存 JSON 字串
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :level
    end
  end
end
