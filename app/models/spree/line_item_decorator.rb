Spree::LineItem.class_eval do

  after_create :add_to_newgistics_shipment_contents, if: lambda {|line_item| line_item.order.can_update_newgistics? }

  after_destroy :remove_from_newgistics_shipment_contents, if: lambda {|line_item| line_item.order.can_update_newgistics? }

  after_update :update_newgistics_shipment_contents, if: lambda { |line_item| line_item.quantity_changed? && line_item.order.can_update_newgistics?}


  ## after a line item is added to the order and if the order state is completed, update newgistics   ## shipment.
  def add_to_newgistics_shipment_contents(qty = self.quantity)
    order.add_newgistics_shipment_content(variant.sku, qty)
  end

  ## after a line item is removed to the order and if the order state is completed update newgistics  ## shipment.
  def remove_from_newgistics_shipment_contents(qty = self.quantity)
    return if qty == 0 # see order_inventory_decorator
    order.remove_newgistics_shipment_content(variant.sku, qty)
  end

  ## If line items quantities change and the order state is completed, update newgistics shipment
  def update_newgistics_shipment_contents
    old_value = changes[:quantity][0]
    new_value = changes[:quantity][1]
    if old_value > new_value
      remove_from_newgistics_shipment_contents(old_value - new_value)
    else
      add_to_newgistics_shipment_contents(new_value - old_value)
    end
  end
end
