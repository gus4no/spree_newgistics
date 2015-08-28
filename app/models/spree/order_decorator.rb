Spree::Order.class_eval do

  after_update :update_newgistics_shipment_address, if: lambda { complete? && ship_address_id_changed? && can_update_newgistics? }

  has_many :state_changes, as: :stateful, after_add: :update_newgistics_shipment_status

  scope :not_in_newgistics, -> { where(state: 'complete', posted_to_newgistics: false) }

  # This method is called everytime a state change in the order happens
  def update_newgistics_shipment_status(state_change)
    Workers::OrderStatusUpdater.perform_async(self.id, state_change.id) if can_update_newgistics?
  end


  # This method is used to update both shipment address and shipment status
  def update_newgistics_shipment_address
    Workers::OrderAddressUpdater.perform_async self.id
  end

  ## This method is called whenever order contents are updated, this is triggered on the after update callback for line items quantity
  def add_newgistics_shipment_content(sku, qty)
    Workers::OrderContentsUpdater.perform_async(self.id, sku, qty, add = true) if complete?
  end

  ## This method is called whenever order contents are updated, this is triggered on the after update callback for line items quantity
  def remove_newgistics_shipment_content(sku, qty)
    Workers::OrderContentsUpdater.perform_async(self.id, sku, qty, add = false) if complete?
  end

  ## This method posts the order to newgisitcs as soon as the checkout ends, if using auto capture
  ## the shipping status would be blank, if not using autocapture the order status would be ONHOLD,
  ## and will be updated as soon as the order changes to 'PAID', if it success, it updates the
  ## posted_to_newgistics flag in the order for further queue updates control.
  def post_to_newgistics
    if complete? && payment_state == 'paid' && !posted_to_newgistics
      Workers::OrderPoster.perform_async self.id
    end
  end

  def can_update_newgistics?
    states = ['returned', 'awaiting_return']
    !states.include?(state.downcase) && posted_to_newgistics?
  end

end
