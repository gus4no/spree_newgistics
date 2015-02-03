module Workers
  class OrderAddressUpdater < AsyncBase
    include Sidekiq::Worker

    def perform(order_id)
      order = Spree::Order.find(order_id)
      document = Spree::Newgistics::DocumentBuilder.build_shipment_updated_address(order)
      response = Spree::Newgistics::HTTPManager.post('/update_shipment_address.aspx', document)
      if update_success?(response)
        order.update_column(:newgistics_status, 'UPDATED')
      else
        raise "Negistics error, response status: #{response.status}"
      end
    end
  end
end
