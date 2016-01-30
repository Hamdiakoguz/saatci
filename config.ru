require File.expand_path('../app/api', __FILE__)

require 'rack/contrib/try_static'
require 'rack/rewrite'

use Rack::TryStatic,
    :root => File.expand_path('../public', __FILE__),
    :urls => %w[/],
    :try => ['.html', 'index.html', '/index.html']

use Rack::Rewrite do
    r301 '/', '/docs/'
end

run Saatci::API
