require "yaml"
require "dropbox_api"
require "paperclip"
require "paperclipdropbox"

namespace :paperclipdropbox do

	desc "Authorize Paperclip link to your Dropbox"
	task authorize: :environment do

		config_file = Paperclip::Storage::Dropbox::CONFIG_FILE
		puts ""
		puts ""
		puts ""

		begin
			dropbox_key = '8ti7qntpcysl91j'
			dropbox_secret = 'i0tshr4cpd1pa4e'

			authenticator = DropboxApi::Authenticator.new(dropbox_key, dropbox_secret)
			auth_url = authenticator.auth_code.authorize_url(token_access_type: 'offline')

			puts ""
			puts "Please go to #{auth_url} and approve the app"
			puts ""
			puts "Please enter you access code"
			access_code = gets.chomp

			access_token = authenticator.auth_code.get_token(access_code)

			if File.exists?("#{Rails.root}#{config_file}")
				config = YAML.load_file("#{Rails.root}#{config_file}") 
			else
				config = {}
			end
			config[:dropbox_key] = dropbox_key
			config[:dropbox_secret] = dropbox_secret
			config[:access_token] = access_token.to_hash

			File.open("#{Rails.root}#{config_file}",'w') do |h| 
				h.write config.to_yaml
			end
			
			puts ""
			puts "Paperclip is now Authorized"

		rescue => error
			p error
			puts "Failed Authorization. Please try again."
		end

		puts ""
		puts ""
	end

end