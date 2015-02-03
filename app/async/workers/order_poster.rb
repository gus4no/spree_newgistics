module Workers
  class OrderPoster < AsyncBase
    include Sidekiq::Worker

    sidekiq_options retry: 3

    def perform(order_id)
      order = Spree::Order.find(order_id)
      document = Spree::Newgistics::DocumentBuilder.build_shipment(order.shipments)
      response = Spree::Newgistics::HTTPManager.post('/post_shipments.aspx', document)
      if response.status <= 299
        errors = Nokogiri::XML(response.body).css('errors').children.any?
        if !errors
          order.update_attributes({posted_to_newgistics: true, newgistics_status: 'RECEIVED'})
        end
      elsif response.status > 399
        raise "Newgistics response failed, status: #{response.status}"
      end
    end
  end
end
