require 'paperclip/url_generator'

module Paperclipdropbox
  class UrlGenerator < Paperclip::UrlGenerator
      def escape_url_as_needed(url, options)
        delimiter_char = url.match(/\?.+=/) ? "&" : "?"
        "#{url}#{delimiter_char}raw=1"
      end
  end
end