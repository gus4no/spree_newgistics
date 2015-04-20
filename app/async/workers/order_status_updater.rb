module Workers
  class OrderStatusUpdater < AsyncBase
    include Sidekiq::Worker

    def perform(order_id, state_change_id)
      order = Spree::Order.find(order_id)
      state_change = Spree::StateChange.find(state_change_id)
      if should_update_newgistics_state?(order, state_change) && can_update_newgistics_state?(order, state_change)
        document = Spree::Newgistics::DocumentBuilder.build_shipment_updated_state(state_change)
        response = Spree::Newgistics::HTTPManager.post('/update_shipment_address.aspx', document)
        if update_success?(response, order.number)
          order.update_column(:newgistics_status, state_change.newgistics_status)
        else
          raise "Negistics error, response status: #{response.status} errors: #{parse_errors(response)}"
        end
      end
    end
  end
end
