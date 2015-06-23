module Workers
  class OrdersPuller < AsyncBase
    include Sidekiq::Worker
    include Sidekiq::Status::Worker
    include ActiveSupport::Callbacks

    def perform
      params = {
          startReceivedTimeStamp: 1.week.ago.strftime('%Y-%m-%d'),
          EndReceivedTimeStamp: Date.tomorrow.strftime('%Y-%m-%d')
      }

      response = Spree::Newgistics::HTTPManager.get('shipments.aspx', params)
      if response.status == 200
        xml = Nokogiri::XML(response.body).to_xml
        shipments = Hash.from_xml(xml)["Shipments"]
        if shipments
          update_shipments(shipments.values.flatten)
        end
      end
    end

    def update_shipments(shipments)
      total 100
      step = 100.0 / shipments.size
      shipments.each_with_index do |shipment, index|
        begin
          order = Spree::Order.find_by(number: shipment['OrderID'])
          log = File.open("#{Rails.root}/log/#{self.jid}_newgistics_orders_import.log", 'a')
          if order
            log << "Updating order: #{ shipment['OrderID'] }\n"
            Spree::Order.skip_callback(:update, :after, :update_newgistics_shipment_address)
            state_id = Spree::State.find_by(abbr: shipment['State']).try(:id)
            country_id = Spree::Country.find_by(iso_name: shipment['Country']).try(:id)
            attributes = {
                newgistics_status: shipment['ShipmentStatus'],
                ship_address_attributes: {
                  firstname: shipment['FirstName'],
                  lastname: shipment['LastName'],
                  company: shipment['Company'],
                  address1: shipment['Address1'],
                  address2: shipment['Address2'],
                  city: shipment['City'],
                  zipcode: shipment['PostalCode'],
                  phone: shipment['Phone']
                }
            }

            attributes[:ship_address_attributes].merge!({state_id: state_id}) if state_id
            attributes[:ship_address_attributes].merge!({country_id: country_id}) if country_id
            order.assign_attributes(attributes)
            order.shipments.update_all(tracking: shipment['Tracking'])
            order.shipments.update_all(newgistics_tracking_url: shipment['TrackingUrl'])
            log << "updating order status\n"
            order.cancel!(:send_email => "true") if order.newgistics_status == 'CANCELED' && !order.canceled?
            log << "updating shipment status\n"
            if order.newgistics_status == 'SHIPPED' && !order.shipped?
              order.shipments.each{ |shipment| shipment.ship! }
              order.send_product_review_email
            end
            if order.changed?
              order.save!
              log << "SUCCESS: Order: #{ shipment['OrderID'] } sucessfully updated."
              Spree::Order.set_callback(:update, :after, :update_newgistics_shipment_address)
            end

          end
        rescue StandardError => e
          log << "ERROR: order: #{shipment['OrderID']} failed due to: #{e.message}\n"
        ensure
          log.close
        end
        progress_at(step * (index + 1)) if index % 5 == 0
      end
      progress_at(100)
      import.log = File.new("#{Rails.root}/log/#{self.jid}_newgistics_orders_import.log", 'r')
      import.save
    end

    def progress_at(progress)
      import.update_attribute(:progress, progress)
      at progress
    end

    def import
      @import ||= Spree::Newgistics::Import.find_or_create_by(job_id: self.jid)
    end

  end
end
