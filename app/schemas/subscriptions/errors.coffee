c = require 'schemas/schemas'

module.exports =
  # app/lib/errors
  'errors:server-error': c.object {required: ['response']},
    response: {type: 'object'}
