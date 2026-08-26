Rails.application.configure do
  config.x.sakte = ActiveSupport::OrderedOptions.new
  config.x.sakte.support_whatsapp = ENV.fetch("SAKTE_SUPPORT_WHATSAPP", "5561999999999")
  config.x.sakte.minimum_age      = 13
  config.x.sakte.max_clip_seconds = 15
  config.x.sakte.max_clip_bytes   = 40.megabytes
end
