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
      Spree::Order.skip_callback(:update, :after, :update_newgistics_shipment_address)

      log_file = "#{Rails.root}/log/#{self.jid}_newgistics_orders_import.log"
      log = File.open(log_file, 'a')



      shipments = shipments.each_with_object({order_ids: [], states: [], countries: [], shipments: {}}) do |shipment, hash|
        hash[:states] << shipment['State']
        hash[:countries] << shipment['Country']
        hash[:order_ids] << shipment['OrderID']
        hash[:shipments][shipment['OrderID']] = shipment
      end

      orders = Spree::Order.where(number: shipments[:order_ids])

      states = Spree::State.where(abbr: shipments[:states]).each_with_object({}) do |state, hash|
        hash[state.abbr] = state
      end

      log << "Found %d states" % states.size

      countries = Spree::Country.where(iso_name: shipments[:countries]).each_with_object({}) do |country, hash|
        hash[country.iso_name] = country
      end

      log << "Found %d countries" % countries.size

      orders.each do |order|

        # delete from shipment hash to reduce future lookup cost since we have
        # 1:1 shipments : orders
        shipment = shipments[:shipments].delete(order.number)

        if shipment.nil?
          log << "Could not find newgistics shipment order_id=%d" % order.id
          next
        end

        state_id = states[shipment['State']].try(:id)
        country_id = countries[shipment['Country']].try(:id)

        {state: state_id, country: country_id}.each do |key, val|
          if val.nil?
            log << "Could not find association %s order_id=%d" % [key, order.id]
          end
        end

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

        if order.changed?
          log << "Updating order_id=%d changes=%s" % [order.id, order.changed]
          order.save!
        end

      end

      progress_at(100)
      import.log = File.new(log_file, 'r')
      import.save

      Spree::Order.set_callback(:update, :after, :update_newgistics_shipment_address)
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
