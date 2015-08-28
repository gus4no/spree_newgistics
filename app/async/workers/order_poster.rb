module Workers
  class OrderPoster < AsyncBase
    include Sidekiq::Worker

    sidekiq_options retry: 3,
                    unique: true,
                    unique_args: ->(args) { [ args.first ] }

    def perform(order_id)
      order = Spree::Order.find(order_id)
      log = File.open("#{Rails.root}/log/#{order.number}_#{Time.now.to_s.gsub(/\s/, "_")}_newgistics_order_poster.log", 'a')
      log << "#{Time.now} - Posting order #{order.id} with number #{order.number}\n"
      if !order.posted_to_newgistics
        log << "Order is being sent to Newgistics\n"
        document = Spree::Newgistics::DocumentBuilder.build_shipment(order.shipments)
        log << "Document: #{document.inspect}\n"
        response = Spree::Newgistics::HTTPManager.post('/post_shipments.aspx', document)
        if update_success?(response, order.number)
          log << "NG responded with status #{response.status}, processing order\n"
          order.update_attributes({posted_to_newgistics: true, newgistics_status: 'RECEIVED'})
          log.close
        else
          errors = Nokogiri::XML(response.body).css('errors').children
          log << "NG responded with status #{response.status} and response has errors\n"
          errors.each { |e| log << "#{e} \n" }
          log.close
          raise "Newgistics response failed, status: #{response.status} and response has errors"
        end
      else
        log << "Order is alredy sent to Newgistics\n"
        log.close
      end
    end
  end
end
