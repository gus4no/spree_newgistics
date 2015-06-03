module Workers
  class OrderStatusUpdater < AsyncBase
    include Sidekiq::Worker

    def perform(order_id, state_change_id)
      order = Spree::Order.find(order_id)
      state_change = Spree::StateChange.find(state_change_id)
      log = File.open("#{Rails.root}/log/#{order.number}_#{Time.now.to_s.gsub(/\s/, "_")}_newgistics_order_status_updater.log", 'a')
      log << "#{Time.now}"
      log << "Posting status change of order #{order.id} with number #{order.number}"
      if should_update_newgistics_state?(order, state_change) && can_update_newgistics_state?(order, state_change)
        document = Spree::Newgistics::DocumentBuilder.build_shipment_updated_state(state_change)
        response = Spree::Newgistics::HTTPManager.post('/update_shipment_address.aspx', document)
        if update_success?(response, order.number)
          log << "Updated status"
          log.close
          order.update_column(:newgistics_status, state_change.newgistics_status)
        else
          log << "Encountered errors while updating status"
          log << "#{parse_errors(response)}"
          log.close
          raise "Negistics error, response status: #{response.status} errors: #{parse_errors(response)}"
        end
      else
        log << "Nothing is done"
        log.close
      end
    end
  end
end
