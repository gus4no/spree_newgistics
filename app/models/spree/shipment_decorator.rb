Spree::Shipment.class_eval do
  def after_cancel
    manifest.each { |item| manifest_restock(item) } unless self.order.posted_to_newgistics
  end
end
