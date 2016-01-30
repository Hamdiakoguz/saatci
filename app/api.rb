require 'rubygems'
require 'grape'
require 'grape-swagger'
require 'json'
require 'maxminddb'
require 'tzinfo'
require 'tzinfo/data'

require 'active_support/core_ext/string'

require_relative 'pretty_json'

module Saatci
  class API < Grape::API
    version 'v1', using: :header, vendor: 'saatci'
    format :json
    formatter :json, Saatci::PrettyJSON

    TZ_ID_REGEXP = /\w+(\/|%2F)[^.]+/
    IP_REGEXP = /(?:[0-9]{1,3}\.){3}[0-9]{1,3}/

    $db = MaxMindDB.new(File.expand_path('../../data/GeoLite2-City.mmdb', __FILE__))

    resource :timezones do
      desc 'Return list of timezone identifiers.'
      get do
        TZInfo::Timezone.all_data_zone_identifiers
      end

      desc 'Return information about a timezone.' do
        detail <<-PARAMS
        Returned information:
        friendly_name: The friendly name of the time zone.
        abbreviation: The abbreviation that identifies this observance
        utc_offset: The current time offset in seconds based on UTC time.
        dst: Whether Daylight Saving Time (DST) is used. true/false
        time: Current local time
        timestamp: Current local time in Unix timestamp.
        PARAMS
      end
      params do
        requires :id, type: String,
                 documentation: { desc: 'Timezone identifier.', example: "Europe/Istanbul" }
      end
      route_param :id, :requirements => { :id => TZ_ID_REGEXP } do
        get do
          begin
            time_zone_info(params[:id])
          rescue TZInfo::InvalidTimezoneIdentifier
            error! :not_found, 404
          end
        end
      end
    end

    resource :ip do
      desc 'Return information about an ip address.'
      params do
        requires :ip, type: String,
                 documentation: { desc: 'IP address.', example: "207.97.227.239" }
      end
      route_param :ip, :requirements => { :ip => IP_REGEXP } do
        get do
          ret = $db.lookup(params[:ip])
          error! :not_found, 404 unless ret.found?
          
          {
            country_code: ret.country.iso_code,
            name: ret.country.name,
            latitude: ret.location.latitude,
            longitude: ret.location.longitude,
            time_zone: (time_zone_info(ret.location.time_zone) rescue ret.location.time_zone),
          }
        end
      end
    end

    resource :version do
      desc "Return information about api and data source versions."
      get do
        {
          tzdata: TZInfo::Data::Version::TZDATA,
          geoLite2_city: "2016-01-05"
        }
      end
    end

    helpers do
      def time_zone_info(id)
        tz = TZInfo::Timezone.get(id)
        time, period = tz.current_time_and_period
        {
          identifier: tz.identifier,
          friendly_name: tz.friendly_identifier, # The friendly name of the time zone.
          abbreviation: period.abbreviation, # The abbreviation that identifies this observance
          utc_offset: period.offset.utc_total_offset, # The current time offset in seconds based on UTC time.
          dst: period.offset.dst?, # Whether Daylight Savinig Time (DST) is used. 1=Yes, 0=No
          time: time, # Current local time
          timestamp: time.to_i # Current local time in Unix timestamp.
        }
      end
    end

    api_desc = <<-DESC

        ## a small timezone information api.

        iana tz database with ruby [tzinfo](https://github.com/tzinfo/tzinfo) library is used for time zone information.
        MaxMind GeoLite2 City database is used with [maxminddb](https://github.com/yhirose/maxminddb) ruby gem for ip location information.

        > This product includes GeoLite2 data created by MaxMind, available from
        > <a href="http://www.maxmind.com">http://www.maxmind.com</a>.

        ---
    DESC

    add_swagger_documentation(
      info: {
        title: "saatci",
        description: api_desc,
        license: "Creative Commons Attribution-ShareAlike 3.0 Unported License",
        license_url: "http://creativecommons.org/licenses/by-sa/3.0/"
      },
      markdown: GrapeSwagger::Markdown::KramdownAdapter,
    )
  end
end