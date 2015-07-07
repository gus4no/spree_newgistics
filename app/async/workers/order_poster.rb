module Workers
  class OrderPoster < AsyncBase
    include Sidekiq::Worker

    sidekiq_options retry: 3

    def perform(order_id)
      order = Spree::Order.find(order_id)
      log = File.open("#{Rails.root}/log/#{order.number}_#{Time.now.to_s.gsub(/\s/, "_")}_newgistics_order_poster.log", 'a')
      log << "#{Time.now}"
      log << "Posting order #{order.id} with number #{order.number}"
      document = Spree::Newgistics::DocumentBuilder.build_shipment(order.shipments)
      response = Spree::Newgistics::HTTPManager.post('/post_shipments.aspx', document)
      if response.status <= 299
        errors = Nokogiri::XML(response.body).css('errors').children
        if !errors.any?
          log << "NG responded with status #{response.status}, processing order"
          order.update_attributes({posted_to_newgistics: true, newgistics_status: 'RECEIVED'})
        else
          log << "NG responded with status #{response.status} with errors:"
          errors.each { |e| puts e }
        end
        log.close
      elsif response.status > 399
        log << "NG responded with status #{response.status}"
        log.close
        raise "Newgistics response failed, status: #{response.status}"
      else
        log.close
      end
    end
  end
end
