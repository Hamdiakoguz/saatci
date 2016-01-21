require 'rubygems'
require 'grape'
require 'json'
require 'maxminddb'
require 'tzinfo'

module Saatci
  class API < Grape::API
    version 'v1', using: :header, vendor: 'saatci'
    format :json

    IP_REGEXP = /(?:[0-9]{1,3}\.){3}[0-9]{1,3}/

    $db = MaxMindDB.new(File.expand_path('../../data/GeoLite2-City.mmdb', __FILE__))

    resource :timezones do
      desc 'Return list of timezone identifiers.'
      get do
        TZInfo::Timezone.all_data_zone_identifiers
      end

      desc 'Return information about a timezone.'
      params do
        requires :id, type: String, desc: 'Timezone identifier.'
      end
      route_param :id, :requirements => { :id => /\w+\/\w+/ } do
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
        requires :ip, type: String, desc: 'IP address.'
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
            time_zone: time_zone_info(ret.location.time_zone),
          }
        end
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
  end
end