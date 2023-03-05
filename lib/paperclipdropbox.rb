module Paperclipdropbox
  require 'paperclipdropbox/railtie' if defined?(Rails)
end

require 'net/http'

module Paperclip
	module Storage
		module Dropbox
    
			CONFIG_FILE = "/config/paperclipdropbox.yml"

			def self.extended(base)
				require "dropbox_api"
				base.instance_eval do
					@options[:escape_url] = false
          unless @options[:url].to_s.match(/\A:dropdox.com\z/)
						@options[:path] = @options[:path].gsub(/:url/, @options[:url]).gsub(/\A:rails_root\/public\/system\//, "")
          	@options[:url]  = ":dropbox_file_url"
          end
				end

        unless Paperclip::Interpolations.respond_to? :dropbox_file_url
          Paperclip.interpolates(:dropbox_file_url) do |attachment, style|
            attachment.public_url(style)
          end
        end
			end

			def exists?(style = default_style)
				begin
					dropbox_client.get_metadata("/#{path(style)}")
					true
				rescue
					false
				end
			end

			def flush_writes
				share_urls = false
				share_urls = {} unless @queued_for_write.empty?
				@queued_for_write.each do |style, file|
					begin
						dropbox_client.upload_by_chunks "/#{path(style)}", file
						public_url(style, file.size)
					rescue
					end
				end
        
        after_flush_writes
        @queued_for_write = {}
			end

			def flush_deletes
				path_styles = styles.keys.push(:original).map {|val| "#{name}_#{val.to_s}"}

				@queued_for_delete.each do |path|
					begin
						
						dropbox_client.delete("/#{path}")
					rescue
					end
				end

				if has_dropbox_share_urls? && !@queued_for_delete.empty?
        	new_share_urls = dropbox_share_urls

        	path_styles.each do |style|
        		new_share_urls.delete(style)
        	end

        	update_dropbox_share_urls(new_share_urls.to_json)if @instance.persisted?
        end

				@queued_for_delete = []
			end

			def public_url(style = default_style, size = 0)

				p "can use cache url = #{can_use_cached_url?("#{name}_#{style}")}" 
				return cached_url(style, size) if can_use_cached_url?("#{name}_#{style}") 

				begin
					shared_link = @options[:default_url]
					shared_link = dropbox_client.list_shared_links(path: "/#{path(style)}").links.first.url+'&raw=1'
				rescue
					shared_link = dropbox_client.create_shared_link_with_settings("/#{path(style)}").url+'&raw=1'
				end

				shared_link = remove_redirects(shared_link, true) if shared_link != @options[:default_url] && size <= max_size

				if has_dropbox_share_urls?
        	new_share_urls = dropbox_share_urls

		    	new_share_urls["#{name}_#{style}"] = shared_link
        	update_dropbox_share_urls(new_share_urls.to_json)
		    end
				shared_link
			end

			private

			def remove_redirects(shared_link, return_last_redirect = false)
				p "removing redirects"
				last_url = URI.parse(shared_link)
				new_url = URI.parse(shared_link)
				loop do 
					new_url.host = last_url.host unless new_url.host
					new_url.scheme = last_url.scheme unless new_url.scheme
					shared_link = new_url.to_s
					new_url = URI.parse(shared_link)

					res = Net::HTTP.get_response(new_url)

					break unless res.is_a?(Net::HTTPRedirection)
					last_url = new_url
					new_url = URI.parse(res['location'])
				end
				
				return last_url.to_s if	return_last_redirect
				
				new_url.to_s
			end

			def dropbox_share_urls
				begin
      		@_dropbox_share_urls ||= JSON.parse(@instance.dropbox_share_urls)
      	rescue
      		@_dropbox_share_urls ||= {}
      	end
			end

			def update_dropbox_share_urls(value)
				@instance.update_column(:dropbox_share_urls, value)
			end

			def has_dropbox_share_urls?
				@instance.has_attribute?(:dropbox_share_urls)
			end

			def max_size
				@_max_size ||= @options['max_file_size'] || 1024 * 1024 * 3
			end

			def cached_url(style = default_style, size = 0)
				if has_dropbox_share_urls?
					remove_url_redirects = @options['remove_url_redirects'] || false

					if dropbox_share_urls.has_key?("#{name}_#{style}")
						p " getting cache for #{name}_#{style}"
						return Rails.cache.fetch("#{@instance.class}_#{@instance.id}_#{name}_#{style}", expires_in: 3.hours) do
							p "rebuilding cache for #{name}_#{style}"
							shared_link = dropbox_share_urls["#{name}_#{style}"]
							shared_link = remove_redirects(shared_link) if remove_url_redirects && size <= max_size

							shared_link
						end
					end
        end

        false
			end

			def can_use_cached_url?(style_key)
				has_dropbox_share_urls? && dropbox_share_urls.has_key?(style_key)
			end

			def dropbox_client
					if @_dropbox_client.blank?
						if File.exists?("#{Rails.root}#{CONFIG_FILE}")
							dropbox_config = YAML.load_file("#{Rails.root}#{CONFIG_FILE}")
							authenticator = DropboxApi::Authenticator.new(dropbox_config[:dropbox_key], dropbox_config[:dropbox_secret])
							access_token = OAuth2::AccessToken.from_hash(authenticator, dropbox_config[:access_token])
							@_dropbox_client = DropboxApi::Client.new(
									access_token: access_token,
	  							on_token_refreshed: lambda { |new_token_hash|
	  								dropbox_config = YAML.load_file("#{Rails.root}#{CONFIG_FILE}")
	  								dropbox_config[:access_token] = new_token_hash
										File.open("#{Rails.root}#{CONFIG_FILE}",'w') do |h| 
											h.write dropbox_config.to_yaml
										end
	  							}
  							)
						else
							warn("#{CONFIG_FILE} does not exist\nEnsure you have authorise paperclipdropbox")
						end
					end
				
				@_dropbox_client
			end
		end
	end
end
