class NewgisticsSyncMailer < ActionMailer::Base
  default from: ENV['NEWGISTICS_NOTIFICATION_FROM_EMAIL'] || "techreports@wearebeautykind.com"
  default to: ENV['NEWGISTICS_NOTIFICATION_TO_EMAIL'] || "techreports@wearebeautykind.com"

  def order_puller_report(job_id, filename, filepath)
    attachments[filename] = File.read(filepath)
    mail(subject: "OrdersPuller job #{job_id} completed with errors",
         body: "See details in attachment")
  end
end
