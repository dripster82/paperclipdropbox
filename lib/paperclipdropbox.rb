module Paperclipdropbox
  require 'paperclipdropbox/railtie' if defined?(Rails)
end

module Paperclip
	module Storage
		module Dropboxstorage
    extend self
    
			def self.extended(base)
				require "dropbox"
				base.instance_eval do
					
					@dropbox_key = '8ti7qntpcysl91j'
					@dropbox_secret = 'i0tshr4cpd1pa4e'
					@dropbox_public_url = "http://dl.dropbox.com/u/"
					@options[:url] ="#{@dropbox_public_url}#{user_id}#{@options[:path]}"
					@url = @options[:url]
					@path = @options[:path]
					log("Starting up DropBox Storage")
				end
			end

			def exists?(style = default_style)
				log("exists?  #{style}") if respond_to?(:log)
				begin
					dropbox_session.metadata("/Public#{File.dirname(path(style))}")
					log("true") if respond_to?(:log)
					true
				rescue
					log("false") if respond_to?(:log)
					false
				end
			end

			def to_file(style=default_style)
				log("to_file  #{style}") if respond_to?(:log)
				return @queued_for_write[style] || "#{@dropbox_public_url}#{user_id}/#{path(style)}"
			end

			def flush_writes #:nodoc:
				log("[paperclip] Writing files #{@queued_for_write.count}")
				@queued_for_write.each do |style, file|
					log("[paperclip] Writing files for ") if respond_to?(:log)
					# Error --> undefined method close for #<Paperclip::
					# file.close
					dropbox_session.upload(file.path, "/Public#{File.dirname(path(style))}", :as=> File.basename(path(style)))
				end
				@queued_for_write = {}
			end

			def flush_deletes #:nodoc:
				@queued_for_delete.each do |path|
					log("[paperclip] Deleting files for #{path}") if respond_to?(:log)
					begin
						dropbox_session.rm("/Public/#{path}")
					rescue
					end
				end
				@queued_for_delete = []
			end

			def user_id
				unless Rails.cache.exist?('DropboxSession:uid')
					log("get Dropbox Session User_id")
					Rails.cache.write('DropboxSession:uid', dropbox_session.account.uid)
					dropbox_session.account.uid
				else
					log("read Dropbox User_id") if respond_to?(:log)
					Rails.cache.read('DropboxSession:uid')
				end
			end

			def dropbox_session
				unless Rails.cache.exist?('DropboxSession')
					if @dropboxsession.blank?
						log("loading session from yaml") if respond_to?(:log)
						if File.exists?("#{Rails.root}/config/dropboxsession.yml")
							@dropboxsession = Dropbox::Session.deserialize(File.read("#{Rails.root}/config/dropboxsession.yml"))
						end
					end
					@dropboxsession.mode = :dropbox unless @dropboxsession.blank?
					@dropboxsession
				else
					log("reading Dropbox Session") if respond_to?(:log)
					Rails.cache.read('DropboxSession')
				end
			end
		end
	end
end
