require "yaml"
require "dropbox"

namespace :paperclipdropbox do


	desc "Create DropBox Authorized Session Yaml"
	task :authorize => :environment do

		SESSION_FILE = "#{Rails.root}/config/dropboxsession.yml"

	    puts ""
	    puts ""
    	puts ""
    
			if File.exists?("#{Rails.root}/config/paperclipdropbox.yml")
				@options = (YAML.load_file("#{Rails.root}/config/paperclipdropbox.yml")[Rails.env].symbolize_keys)
			end
	      
			@dropbox_key = @options.blank? ? '8ti7qntpcysl91j' : @options[:dropbox_key]
			@dropbox_secret = @options.blank? ? 'i0tshr4cpd1pa4e' : @options[:dropbox_secret]

			@dropboxsession = Dropbox::Session.new(@dropbox_key, @dropbox_secret)
			@dropboxsession.mode = :dropbox

	      	puts "Visit #{@dropboxsession.authorize_url} to log in to Dropbox. Hit enter when you have done this."

	      	STDIN.gets

		begin
			@dropboxsession.authorize
      		puts ""
			puts "Authorized - #{@dropboxsession.authorized?}"
		rescue
			begin
        		puts ""
				puts "Please login to dropbox using this link : #{@dropboxsession.authorize_url}"
				puts "then run this rake task again."
			rescue
        		puts ""
				puts "Already Authorized - #{@dropboxsession.authorized?}"
			end
		end

		puts ""
		puts ""
		File.open(SESSION_FILE, "w") do |f|
			f.puts @dropboxsession.serialize
		end
	end

end