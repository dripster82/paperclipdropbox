require "yaml"
require "dropbox"

namespace :paperclipdropbox do


	desc "Create DropBox Authorized Session Yaml"
	task :authorize => :environment do

		SESSION_FILE = "#{Rails.root}/config/dropboxsession.yml"

		puts ""
		puts ""
		puts ""

		@dropboxsession = Paperclip::Storage::Dropboxstorage.dropbox_session

		if @dropboxsession.blank?
			if File.exists?("#{Rails.root}/config/paperclipdropbox.yml")
				@options = (YAML.load_file("#{Rails.root}/config/paperclipdropbox.yml")[Rails.env].symbolize_keys)
			end

			@dropbox_key = @options[:dropbox_key].blank? ? '8ti7qntpcysl91j' : @options[:dropbox_key]
			@dropbox_secret = @options[:dropbox_secret].blank? ? 'i0tshr4cpd1pa4e' : @options[:dropbox_secret]

			@dropboxsession = Dropbox::Session.new(@dropbox_key, @dropbox_secret)
			@dropboxsession.mode = :dropbox

			puts "Visit #{@dropboxsession.authorize_url} to log in to Dropbox. Hit enter when you have done this."

			STDIN.gets

		end

		begin
			@dropboxsession.authorize
			puts ""
			puts "Authorized - #{@dropboxsession.authorized?}"
		rescue
			begin
				puts ""
				puts "Visit #{@dropboxsession.authorize_url} to log in to Dropbox. Hit enter when you have done this."

				STDIN.gets
				@dropboxsession.authorize
				puts ""
				puts "Authorized - #{@dropboxsession.authorized?}"
			rescue
				puts ""
				puts "Already Authorized - #{@dropboxsession.authorized?}" unless @dropboxsession.blank?
				puts "Failed Authorization. Please try delete /config/dropboxsession.yml and try again." if @dropboxsession.blank?
			end
		end

		puts ""
		puts ""
		unless @dropboxsession.blank?
			File.open(SESSION_FILE, "w") do |f|
				f.puts @dropboxsession.serialize
			end
		end
	end

end