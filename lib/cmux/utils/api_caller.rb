module CMUX
  module Utils
    # Request APIs.
    module ApiCaller
      class << self
        # Send get request.
        def get_req(args = {})
          res = req_impl(Net::HTTP::Get, args)
          res_impl(res, args)
        end

        # Send put request.
        def put_req(args = {})
          res = req_impl(Net::HTTP::Put, args)
          res_impl(res, args)
        end

        # Send post request.
        def post_req(args = {})
          res = req_impl(Net::HTTP::Post, args)
          res_impl(res, args)
        end

        private

        def req_impl(klass, args = {})
          uri = URI(args[:url])
          req = set_req(klass, uri, args)

          Net::HTTP.start(
            uri.host,
            uri.port,
            open_timeout: args[:open_timeout] || 10,
            use_ssl: uri.scheme == 'https',
            verify_mode: OpenSSL::SSL::VERIFY_NONE
          ) { |http| http.request(req) }
        end

        def res_impl(res, args = {})
          case res
          when Net::HTTPSuccess
            return res.body if args[:raw]
            body = JSON.parse(res.body, symbolize_names: args[:sym_name])
            args[:props] ? body[args[:props]] : body
          else
            raise StandardError, "#{res.code} #{res.message}"
          end
        end

        def set_req(klass, uri, args)
          req = klass.new(uri, args[:headers])
          req.basic_auth args[:user], args[:password]
          req.body = args[:body]
          req
        end
      end
    end
  end
end
