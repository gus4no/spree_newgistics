module Spree
  module Newgistics
    module RequiredAttributes
      ATTRIBUTES = [
        :product_attributes,
        :order_attributes,
        :manifest_attributes,
        :inventory_attributes,
        :return_attributes,
        :item_attributes,
        :address_update_attributes,
        :shipment_state_update_attributes
      ]

      mattr_reader *ATTRIBUTES

      @@product_attributes = {
          sku: :sku,
          width: :width,
          height: :height,
          weight: :weight,
          retail_value: [:price, :to_s],
          ship_from: 'Newgistics',
          country_of_origin: 'US',
          is_active: [:product, :available?]
      }

      @@order_attributes = {
          customer_info: {
            company: [:order, :ship_address, :company],
            first_name: [:order, :ship_address, :first_name],
            last_name: [:order, :ship_address, :last_name],
            address1: [:order, :ship_address, :address1],
            address2: [:order, :ship_address, :address2],
            city: [:order, :ship_address, :city],
            state: [:order, :ship_address, :state, :name],
            zip: [:order, :ship_address, :zipcode],
            country: [:order, :ship_address, :country, :iso],
            email: [:order, :email],
            phone: [:order, :ship_address, :phone]
          },
          order_date: [:order, :completed_at, { strftime: '%m/%d/%Y' }],
          ship_method: [:shipping_method, :admin_name],
          items: :line_items
      }

      @@shipment_state_update_attributes = {
        address1: [:stateful, :ship_address, :address1],
        city: [:stateful, :ship_address, :city],
        state: [:stateful, :ship_address, :state, :name],
        postal_code: [:stateful, :ship_address, :zipcode],
        country: [:stateful, :ship_address, :country, :iso],
        status: :newgistics_status,
        status_notes: :newgistics_status_notes
      }

      @@address_update_attributes = {
        first_name: [:ship_address, :first_name],
        last_name: [:ship_address, :last_name],
        company: [:ship_address, :company],
        address1: [:ship_address, :address1],
        address2: [:ship_address, :address2],
        city: [:ship_address, :city],
        state: [:ship_address, :state, :name],
        postal_code: [:ship_address, :zipcode],
        country: [:ship_address, :country, :iso],
        email: [:email],
        phone: [:ship_address, :phone],
        status: 'UPDATED',
        status_notes: 'Address updated'

      }

      @@item_attributes = {
          SKU: [:variant, :sku],
          qty: :quantity
      }
    end
  end
end
