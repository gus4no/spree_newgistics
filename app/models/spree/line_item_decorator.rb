Spree::LineItem.class_eval do

  durably_decorate :update_inventory do
    sync_to_newgistics_if_needed
    original_update_inventory
  end

  def sync_to_newgistics_if_needed
    return unless self.order.can_update_newgistics?
    diff = self.quantity - self.inventory_units.size
    if diff > 0
      order.add_newgistics_shipment_content(variant.sku, diff)
    else
      order.remove_newgistics_shipment_content(variant.sku, -diff)
    end
  end
end
