class Interceptor

  # stubbing sinatra helpers used by the views
  class TemplateContext
    def current_identity
      nil
    end
  end

  class Callback

    attr_accessor :validator, :post
    def initialize(validator, post)
      self.validator = validator
      self.post = post
    end

    def execute
      code, response = perform_request
      if (200...300).include? code
        update_per response
      elsif code == 403
        fail UnauthorizedChangeError.new(response)
      else
        fail StandardError.new(response)
      end
      post
    end

    def update_per(response)
      response = JSON.parse(response)
      return unless response["status"] == "revised"
      response["changes"].each do |key, value|
        post.send("#{key}=".to_sym, value)
      end
    end

    def perform_request
      curl = Curl::Easy.http_post(validator.url, request_body)
      [curl.response_code, curl.body_str]
    end

    def request_body
      template = 'api/v1/views/callback_post.pg'
      Petroglyph::Engine.new(File.read(template)).render(TemplateContext.new, {:mypost => post}, template)
    end

  end
end
