module Workers
  class OrderContentsUpdater < AsyncBase
    include Sidekiq::Worker

    def perform(order_id, sku, qty, add)
      if qty > 0
        order = Spree::Order.find(order_id)
        document = Spree::Newgistics::DocumentBuilder.build_shipment_contents(order.number, sku, qty, add)
        response = Spree::Newgistics::HTTPManager.post('/update_shipment_contents.aspx', document)
        if update_success?(response, order.number)
          order.update_column(:newgistics_status, 'UPDATED')
        else
          raise "Negistics error, response status: #{response.status} errors: #{parse_errors(response)}"
        end
      end
    end
  end
end
