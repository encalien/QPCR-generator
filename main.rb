require "sinatra"
require "json"
require_relative "qpcr_generator.rb"

get "/" do
  erb :data_form
end

post "/" do
  data = JSON.parse(params[:file][:tempfile].read)
  generator = QPCRGenerator.new(
    data["max_well_count"], data["sample_list"], data["reagent_list"], data["replicate_count"]
  )
  plates = generator.filled_plates
  colors = generator.set_color_codes
  erb :plate_layout, locals: {plates: plates, colors: colors}
end