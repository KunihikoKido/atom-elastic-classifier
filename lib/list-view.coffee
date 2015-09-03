{$$, SelectListView} = require 'atom-space-pen-views'

module.exports =
class ListView extends SelectListView
  initialize: (@items, @callback)->
    super
    @setItems(@items)
    @panel ?= atom.workspace.addModalPanel(item: this)
    @panel.show()
    @focusFilterEditor()

  getFilterKey: -> 'name'

  viewForItem: ({name}) ->
    $$ -> @li(name)

  hide: -> @panel?.hide()

  confirmed: (item) ->
    @callback?(item)
    @hide()

  cancelled: ->
    @onCancel?()
    @hide()
