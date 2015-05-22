Spree::LineItem.class_eval do

  alias_method :old_update_inventory, :update_inventory

  def update_inventory
    sync_to_newgistics if self.order.can_update_newgistics?
    old_update_inventory    
  end

  def sync_to_newgistics
    diff = self.quantity - self.inventory_units.size
    if diff > 0
      order.add_newgistics_shipment_content(variant.sku, diff)
    else
      order.remove_newgistics_shipment_content(variant.sku, diff.abs)
    end
  end
end
