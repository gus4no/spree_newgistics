module Spree
  module Newgistics
    class Import < ActiveRecord::Base

      self.table_name = 'spree_newgistics_imports'

      def self.attachment_path
        if ENV['AWS_S3_BUCKET_NAME']
          'logs/:id/:basename.:extension'
        else
          ':rails_root/public/spree/logs/:id/:basename.:extension'
        end
      end
      has_attached_file :log,
                        url: '/spree/logs/:id/:basename.:extension',
                        path: Spree::Newgistics::Import.attachment_path

      def as_json(options={})
        {
            id: id,
            job_id: job_id,
            status: status,
            log_url: log.url,
            progress: progress
        }
      end

    end
  end
end