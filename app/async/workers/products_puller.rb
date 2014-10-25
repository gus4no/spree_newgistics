module Workers
  class ProductsPuller < AsyncBase
    include Sidekiq::Worker
    include Sidekiq::Status::Worker


    def perform
      response = Spree::Newgistics::HTTPManager.get('products.aspx')
      if response.status == 200
        xml = Nokogiri::XML(response.body).to_xml
        products = Hash.from_xml(xml)["products"]
        if products
          save_products(products.values.flatten)
        end
      else
        Spree::Newgistics::Import.find_or_create_by(job_id: job_id,  details: 'Newgistics request failed')
      end
    end

    def save_products(products)
      total 100
      step = 100.0 / products.size
      disable_callbacks
      products.each_with_index do |product, index|
        begin
          log = File.open("#{Rails.root}/log/#{self.jid}_newgistics_import.log", 'a')
          spree_variant = Spree::Variant.find_by(sku: product['sku'])

          if spree_variant
            log << "updating sku: #{product['sku']}\n"
            spree_variant.update_attributes!({ upc: product['upc'],
                                               cost_price: product['value'].to_f,
                                               price: product['retailValue'].to_f,
                                               height: product['height'].to_f,
                                               width: product['width'].to_f,
                                               weight: product['weight'].to_f,
                                               depth: product['depth'].to_f,
                                               vendor_sku: product['supplierCode'],
                                               vendor: product['supplier'],
                                               newgistics_active: product['isActive'] == 'true' ? true : false })
          else

            color_code = product['sku'].match(/-([^-]*)$/).try(:[],1).to_s

            ## if sku has color code it means we need to build and group variants together
            if color_code.present?

              ## build a master variant sku which would be the same color code with 0000
              product_code = product['sku'].match(/^(.*)-/)[1].to_s
              master_variant_sku = "#{product_code}-00"
              master_variant = Spree::Variant.find_by(sku: master_variant_sku)

              ## if we already have a master variant it means a product has been created
              ## let's just add a new variant to the product.
              ## else create a new product, let spree callbacks create the master variant
              ## and change the sku to the one we want.
              if master_variant
                log << "creating color code: #{ product['sku'] } for sku: #{master_variant_sku}\n"

                variant = master_variant.product.variants.new(get_attributes_from(product))
                variant.assign_attributes(variant_attributes_from(product))
                variant.save!
              else
                spree_product = Spree::Product.new(get_attributes_from(product))
                spree_product.taxons << supplier_from(product) if product['supplier'].present?
                log << "creating created master sku for grouping: #{master_variant_sku}\n"
                spree_product.master.assign_attributes(variant_attributes_from(product).merge({ sku: master_variant_sku }))

                log << "creating created color code: #{ product['sku'] } for sku: #{master_variant_sku}\n"
                spree_variant = Spree::Variant.new(get_attributes_from(product))
                spree_variant.assign_attributes(variant_attributes_from(product))
                spree_variant.save!

                spree_product.variants << spree_variant
                spree_product.save!
              end

            else
              log << "creating created sku: #{product['sku']}\n"

              spree_product = Spree::Product.new(get_attributes_from(product))
              spree_product.taxons << supplier_from(product) if product['supplier'].present?

              master = spree_product.master


              spree_product.save!
              master.update_attributes!(variant_attributes_from(product))

              additional_variant = master.dup
              additional_variant.is_master = false
              additional_variant.save!

              spree_product.variants << additional_variant
              spree_product.save!
              master.update_attributes!({ sku: "#{product['sku']}-00" })

            end
            log << "SUCCESS: created sku: #{product['sku']}\n"
          end
        rescue StandardError => e
          log << "ERROR: sku: #{product['sku']} failed due to: #{e.message}\n"
        ensure
          log.close
        end
        progress_at(step * (index + 1)) if index % 5 == 0
      end
      progress_at(100)
      import.log = File.new("#{Rails.root}/log/#{self.jid}_newgistics_import.log", 'r')
      import.save
      enable_callbacks
    end

    def progress_at(progress)
      import.update_attribute(:progress, progress)
      at progress
    end

    def import
      @import ||= Spree::Newgistics::Import.find_or_create_by(job_id: self.jid)
    end

    def supplier_from(product)
      find_supplier(product['supplier']) || create_supplier(product["supplier"])
    end

    def find_supplier(name)
      @taxonomy ||= Spree::Taxonomy.find_by(name: 'Brands')
      @brands ||= @taxonomy.root.children
      @brands.reload.where("LOWER(spree_taxons.name) = LOWER('#{name.downcase}')").first
    end

    def create_supplier(name)
      @taxonomy ||= Spree::Taxonomy.find_by(name: 'Brands')
      @brands ||= @taxonomy.root.children
      @brands.reload.create!(name: name.downcase.camelcase, permalink: "brands/#{name.downcase.split(' ').join('-')}", taxonomy_id: @taxonomy.id)
    end

    def disable_callbacks
      Spree::Variant.skip_callback(:create, :after, :post_to_newgistics)
      Spree::Variant.skip_callback(:update, :after, :post_to_newgistics)
      Spree::Variant.skip_callback(:save, :after, :enqueue_product_for_reindex)
      Spree::Variant.skip_callback(:create, :before, :ensure_color_code)
      Spree::Product.skip_callback(:commit, :after, :enqueue_for_reindex)
    end

    def enable_callbacks
      Spree::Variant.set_callback(:create, :after, :post_to_newgistics)
      Spree::Variant.set_callback(:update, :after, :post_to_newgistics)
      Spree::Variant.set_callback(:save, :after, :enqueue_product_for_reindex)
      Spree::Variant.set_callback(:create, :before, :ensure_color_code)
      Spree::Product.set_callback(:commit, :after, :enqueue_for_reindex)
    end

    def variant_attributes_from(product)
      item_category_id = product["category"].present? ? Spree::ItemCategory.find_or_create_by!(name: product["category"].downcase.camelcase).id : nil

      {
          posted_to_newgistics: true,
          item_category_id: item_category_id,
          upc: product['upc'],
          vendor_sku: product['supplierCode'],
          vendor: product['supplier'],
          newgistics_active: product['isActive'] == 'true' ? true : false
      }
    end

    def get_attributes_from(product)
      {
          sku: product['sku'],
          name: product['description'],
          description: product['description'],
          slug: product['description'].present? ? product['description'].downcase.split(' ').join('-') : '',
          upc: product['upc'],
          cost_price: product['value'].to_f,
          price: product['retailValue'].to_f,
          height: product['height'].to_f,
          width: product['width'].to_f,
          weight: product['weight'].to_f,
          depth: product['depth'].to_f,
          available_on: product['isActive'] == 'true' ? Time.now : nil,
          shipping_category_id: 1
      }
    end
  end
end
