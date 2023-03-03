require "yaml"
require "dropbox_api"

namespace :paperclipdropbox do


	desc "Authorize Paperclip link to your Dropbox"
	task :authorize => :environment do


		puts ""
		puts ""
		puts ""

		begin
			puts "You need to have a dropbox app created under your own account."
			puts "If you don't have one please goto https://www.dropbox.com/developers/apps"
			puts ""
			puts "Please enter your App Key"
			dropbox_key = gets.chomp #'8ti7qntpcysl91j'

			puts ""
			puts "Please enter your App Secret"
			dropbox_secret = gets.chomp #'i0tshr4cpd1pa4e'

			authenticator = DropboxApi::Authenticator.new(dropbox_key, dropbox_secret)
			auth_url = authenticator.auth_code.authorize_url(token_access_type: 'offline')

			puts ""
			puts "Please go to #{auth_url} and approve the app"
			puts ""
			puts "Please enter you access code"
			access_code = gets.chomp

			access_token = authenticator.auth_code.get_token(access_code)

			if File.exists?("#{Rails.root}/config/paperclipdropbox.yml")
				config = YAML.load_file("#{Rails.root}/config/paperclipdropbox.yml") 
			else
				config = {}
			end
			config[:dropbox_key] = dropbox_key
			config[:dropbox_secret] = dropbox_secret
			config[:access_token] = access_token.to_hash

			File.open("#{Rails.root}/config/paperclipdropbox.yml",'w') do |h| 
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