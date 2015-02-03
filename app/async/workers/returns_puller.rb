module Workers
  class ReturnsPuller < AsyncBase
    include Sidekiq::Worker
    include ActiveSupport::Callbacks


    def perform
      params = {
          StartTimeStamp: 1.day.ago.strftime('%Y-%m-%d'),
          EndTimeStamp: Date.tomorrow.strftime('%Y-%m-%d')
      }

      response = Spree::Newgistics::HTTPManager.get('returns.aspx', params)
      if response.status == 200
        xml = Nokogiri::XML(response.body).to_xml
        returns = Hash.from_xml(xml)["Returns"]
        if returns
          update_shipments(returns.values.flatten)
        end
      end
    end

    def update_shipments returns
      Spree::Order.skip_callback(:update, :after, :update_newgistics_shipment_address)

      returns.each do |returned_shipment|
        order = Spree::Order.find_by(number: returned_shipment['orderID'])
        if order && order.can_update_newgistics?

          items = returned_shipment["Items"].try(:values).try(:flatten)
          if items
            amount = 0

            rma = order.return_authorizations.create(reason: returned_shipment["Reason"])

            items.each do |returned_item|

              variant = Spree::Variant.find_by(sku: returned_item["SKU"])
              if variant
                rma.add_variant(variant.id, returned_item["QtyReturned"].to_i)
                amount += variant.price * returned_item["QtyReturned"].to_i
              end
            end

            rma.amount = amount

            order.update_column(:newgistics_status, returned_shipment["Status"])
            rma.save!
            rma.receive!

            Spree::Order.set_callback(:update, :after, :update_newgistics_shipment_address)
          end
        end
      end
    end

  end
end
