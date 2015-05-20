Spree::OrderInventory.class_eval do
  durably_decorate :remove do |item_units, *args|
    # in case we delete line_item from line_item api controller
    # we set quantity to 0 before destroying line_item 
    # but before this method will be called with existing item_units
    if @order.can_update_newgistics? && @line_item.quantity == 0
      quantity = item_units.size
      @order.remove_newgistics_shipment_content(variant.sku, quantity)
    end
    original_remove item_units, *args
  end
end