class AddNewgisticsTrackingUrlToShipments < ActiveRecord::Migration
  def change
    add_column :spree_shipments, :newgistics_tracking_url, :text
  end
end
