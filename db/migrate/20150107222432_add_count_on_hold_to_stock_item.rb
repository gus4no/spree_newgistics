class AddCountOnHoldToStockItem < ActiveRecord::Migration
  def change
    add_column :spree_stock_items, :count_on_hold, :integer, default: 0
  end
end
