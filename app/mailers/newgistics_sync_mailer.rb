class NewgisticsSyncMailer < ActionMailer::Base
  default from: "techreports@wearebeautykind.com"
  default to: "e.sypachev@foxcommerce.com"

  def order_puller_report(filename, filepath)
    attachments[filename] = File.read(filepath)
    mail(subject: 'OrdersPuller job completed with errors')
  end
end
