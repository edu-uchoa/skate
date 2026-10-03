Rails.application.configure do
  config.x.stance = ActiveSupport::OrderedOptions.new
  config.x.stance.support_whatsapp = ENV.fetch("STANCE_SUPPORT_WHATSAPP", "5561999999999")
  config.x.stance.minimum_age      = 13
  config.x.stance.max_clip_seconds = 15
  config.x.stance.max_clip_bytes   = 40.megabytes
end
