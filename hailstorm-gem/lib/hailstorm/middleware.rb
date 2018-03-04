require 'hailstorm'

# Middleware is the 'rack' of rack based applications - it gives access to all of Hailstorm's features by encapsulating
# a command interpreter and executor. The middleware can then be mounted on any application front-end such as CLI, HTTP
# API, RPC etc. The 'mount' will in most cases be done with a 'decorator' pattern.
module Hailstorm::Middleware
end
