class AddSpreeNewgisticsImports < ActiveRecord::Migration
  def change
    create_table :spree_newgistics_imports do |t|
      t.string :job_id
      t.string :status, default: 'working'
      t.string :details
      t.float :progress, default: 0
      t.timestamps
    end

    add_attachment :spree_newgistics_imports, :log
  end
end
