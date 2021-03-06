/*

Extra bits that make CM a better editor to learn with:
- When editing an element in CM, it is shown and highlighted in the preview
- If you click and element in the preview, the corresponding text is selected in the editor.
- Show errors in HTML / CSS

*/

require! {
  'game/editor/Errors'
  'game/editor/utils'
  'lib/channels'
  'lib/lang/html'
  'lib/tree-inspectors'
  'settings'
}

constrain = (n, min, max) ->
  | n < min => min
  | n > max => max
  | otherwise => n

error-root = "/#{settings.get \lang}/data/"
errors = new Errors error-root
errors.load <[all]>, (err) ->
  if err? then channels.alert.publish msg: err

module.exports = setup-CM-extras = (cm, render-el) ->
  last-mark = false
  marks = []
  cm.data = {}

  clear-cursor-marks = ->
    if last-mark?.data?.node? then last-mark.data.node.class-list.remove 'editing-current-active'

  convert-range = (range) ->
    start = cm.pos-from-index range.start
    end = cm.pos-from-index range.end
    {inclusive-left, inclusive-right} = range
    if range.start <= 0 then inclusive-left ?= true
    if range.end >= cm.get-value!.length then inclusive-right ?= true

    {start, end, inclusive-left, inclusive-right}

  highlight-current-element = ~>
    if last-mark isnt false then clear-cursor-marks!

    pos = cm.get-cursor!
    posmarks = cm.find-marks-at pos
    if posmarks.length isnt 0
      mark = posmarks[posmarks.length - 1]

      if mark.data isnt undefined
        mark.data.node.class-list.add 'editing-current-active'
        show-element mark.data.node, render-el

        last-mark := mark

  cm.on "cursorActivity", highlight-current-element

  read-only-marks = []
  highlight-marks = []

  return {
    process: (html-src) ->
      parsed = html.to-dom html-src

      clear-marks!
      link-to-preview parsed.document, marks, cm

      show-error cm, parsed.error

      # Remove JS:
      jses = tree-inspectors.find-JS parsed.document

      for js in jses
        if js.type is "SCRIPT_ELEMENT"
          js.node.parent-node.remove-child js.node
        if js.type is "EVENT_HANDLER_ATTR" or js.type is "JAVASCRIPT_URL"
          js.node.owner-element.attributes.remove-named-item js.node.name

      highlight-current-element!

      return parsed

    mark-readonly: (range) ->
      range = convert-range range
      mark = cm.mark-text range.start, range.end, {
        read-only: true
        range.inclusive-left
        range.inclusive-right
        css: 'opacity: 0.5; cursor: not-allowed;'
        atomic: true
      }
      mark.eak-read-only-mark = true
      read-only-marks[*] = mark

    clear-readonly: ({start, end, inclusive-left, inclusive-right}) ->
      remove = (mark) ->
        mark.clear!
        read-only-marks.splice (read-only-marks.index-of mark), 1

      marks = cm.get-all-marks! .filter ( .eak-read-only-mark )

      for mark in marks
        pos = mark.find!
        unless pos
          remove mark
          continue

        mark-start = cm.index-from-pos pos.from
        mark-end = cm.index-from-pos pos.to

        switch
        # no intersection - ignore the mark
        case end <= mark-start or start >= mark-end => # meh

        # range fully contains mark - remove the mark
        case start <= mark-start and mark-end <= end => remove mark

        # mark fully contains range - split mark in two
        case mark-start < start and end < mark-end
          remove mark
          @mark-readonly {start: mark-start, end: start, mark.inclusive-left, inclusive-right}
          @mark-readonly {start: end, end: mark-end, inclusive-left, mark.inclusive-right}

        # range clips left edge of mark
        case start <= mark-start < end
          remove mark
          @mark-readonly {start: end, end: mark-end, inclusive-left, mark.inclusive-right}

        # range clips right edge of mask
        case start < mark-end <= end
          remove mark
          @mark-readonly {start: mark-start, end: start, mark.inclusive-left, inclusive-right}

        default => console.error "Cannot remove read-only range:" {mark, range, start, end, mark-start, mark-end}

    clear-cursor-marks: clear-cursor-marks

    highlight: (range) ->
      range = convert-range range
      highlight-marks[*] = cm.mark-text range.start, range.end,
        class-name: \highlight-action

    clear-highlight: ->
      highlight-marks.for-each ( .clear! )
      highlight-marks := []
  }

clear-marks = (marks) ->
  if marks isnt undefined
    until (mark = marks.shift!) is undefined
      mark.clear!

$level-container = $ '#levelcontainer'
level-container = $level-container.get 0
show-element = (el, parent) ->
  target-x = $body.width! * 0.75
  target-y = $body.height! / 2
  rect = el.get-bounding-client-rect!
  current-x = rect.left + rect.width / 2
  current-y = rect.top + rect.height / 2
  if current-x is 0 or current-y is 0 then return

  x-diff = current-x - target-x
  y-diff = current-y - target-y
  max-scroll-x = Math.max 0, level-container.scroll-width - level-container.client-width
  max-scroll-y = Math.max 0, level-container.scroll-height - level-container.client-height

  $level-container.stop!.animate {
    scroll-left: constrain level-container.scroll-left + x-diff, 0, max-scroll-x
    scroll-top: constrain level-container.scroll-top + y-diff, 0, max-scroll-y
  }, 100

show-error = (cm, err) ->

  if cm.data.err-line isnt undefined
    cm.remove-line-class cm.data.err-line, \wrap, 'slowparse-error'
    cm.data.err-widget.clear!
    cm.data.err-line = cm.data.err-widget = undefined

  if cm.data.tmp-markers isnt undefined
    clear-marks cm.data.tmp-markers

  if err isnt null
    error = errors.get-error err
    pos = utils.get-positions err, cm

    error.add-class 'annotation-widget annotation-error'

    cm.data.err-line = line = pos.start.inner.line

    cm.add-line-class cm.data.err-line, \wrap, 'slowparse-error'
    cm.data.err-widget = cm.add-line-widget line, error.0, {+cover-gutter, +no-h-scroll}

    # Highlight links in error messages:
    highlighters = error.find '[data-highlight]'
    highlighters.on \mouseover, ->
      highlight = $ @
      hl = highlight.data \highlight
      if typeof hl is \number
        return

      range = highlight.data \highlight .split ','
      start = cm.pos-from-index range.0
      end = cm.pos-from-index range.1
      marker = cm.mark-text start, end, className: 'highlight-error'

      if cm.data.tmp-markers is undefined
        cm.data.tmp-markers = [marker]
      else
        cm.data.tmp-markers[*] = marker

      highlight.data 'cm-error.marker' marker

    highlighters.on \mouseout, ->
      highlight = $ @
      marker = highlight.data 'cm-error.marker'
      if marker isnt undefined
        marker.clear!

    highlighters.on 'click', ->
      highlight = $ @
      hl = highlight.data \highlight
      if typeof hl is \number
        pos = cm.pos-from-index hl
        cm.set-cursor pos
      else
        range = highlight.data \highlight .split ','
        start = cm.pos-from-index range.0
        end = cm.pos-from-index range.1
        cm.setSelection start, end

      cm.focus!

link-to-preview = (node, marks, cm) ~>
  if node.parse-info isnt undefined and node.node-type is 1

    pos = utils.get-positions node.parse-info, cm

    mark = cm.mark-text pos.start.outer, pos.end.outer

    mark.data = node: node
    marks[*] = mark

    node.add-event-listener \click, (e) ~>
      e.stop-propagation!

      cm.set-selection pos.start.inner, pos.end.inner
      cm.focus!

    , false

  for n in node.child-nodes
    link-to-preview n, marks, cm

