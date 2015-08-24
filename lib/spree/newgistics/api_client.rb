module Spree
  module Newgistics
    class ApiClient
      class << self
        def orders(params)
          response = Spree::Newgistics::HTTPManager.get('shipments.aspx', params)
          if response.status == 200
            xml = Nokogiri::XML(response.body).to_xml
            shipments = Hash.from_xml(xml)["Shipments"]
            return shipments
          else
            raise RuntimeError, "Newgistics responded with status: #{response.status}"
          end
        end
      end
    end
  end
end
