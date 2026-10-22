# frozen_string_literal: true

class CreateSharedRoots < ActiveRecord::Migration[8.1]
  def change
    create_table :shared_roots, id: :uuid do |t|
      t.string :name, null: false
      t.timestamps
    end
  end
end