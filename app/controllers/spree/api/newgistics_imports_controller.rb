module Spree
  module Api
    class NewgisticsImportsController < Spree::Api::BaseController

      def products
        if current_spree_user.admin?
          job_id = Workers::ProductsPuller.perform_async
          @import = Spree::Newgistics::Import.find_or_create_by(job_id: job_id, progress: 5)
          render json: @import.to_json
        end
      end

      def orders
        if current_spree_user.admin?
          job_id = Workers::OrdersPuller.perform_async
          @import = Spree::Newgistics::Import.find_or_create_by(job_id: job_id, progress: 5)
          render json: @import.to_json
        end
      end

      def status
        @import = Spree::Newgistics::Import.find_by(job_id: params[:job_id])
        @import.assign_attributes(status: Sidekiq::Status::status(params[:job_id]))
        @import.save if @import.changed?
        render json: @import
      end
    end
  end
end