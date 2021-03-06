(($) ->
  ComponentEditor = (->
    getValue = (element) ->
      if element.attr('type') == 'checkbox'
        element.is(':checked')
      else
        if element.data('component-config-type') == 'json'
          JSON.parse(element.val())
        else
          element.val()

    setValue = (element, value) ->
      if element.attr('type') == 'checkbox'
        element.prop('checked', value)
      else
        if element.data('component-config-type') == 'json'
          element.val(JSON.stringify(value))
        else
          element.val(value)

    ensureExist = (config, key) ->
      struct = config
      for field in key.split('.')
        struct[field] = {} unless struct[field]?
        struct = struct[field]

    setValues = (editor, values, selector, filter_selector = "data-role='component'") ->
      $("[#{selector}]", editor).not($("[#{filter_selector}] [#{selector}]", editor)).each ->
        element = $(this)
        value = eval("values.#{element.attr(selector)}")
        setValue(element, value) if value?
      editor

    getValues = (editor, values, selector, filter_selector="data-role='component'") ->
      $("[#{selector}]", editor).not($("[#{filter_selector}] [#{selector}]", editor)).each ->
        element = $(this)
        key = element.attr(selector)
        ensureExist(values, key) if key.indexOf('.') != -1
        eval("values.#{key} = getValue(element)")
        return true
      values


    getConfiguration: (editor) -> getValues(editor, editor.data('component-config') || {}, 'data-component-config-key')
    setConfiguration: (editor, value) -> setValues(editor, value, 'data-component-config-key')

    getContent: (editor) ->  getValues(editor, editor.data('component-content') || {}, 'name')

    create: (target, component, config, content) ->
      editor = setValues(component.editor(target, config, content), config, 'data-component-config-key')
      setValues(editor, content, 'name') if content?
      editor
  )()

  ContentComponent = (api, spi) ->
    components = {}

    IdGenerator =(->
      componentIds = {}

      next: (type) ->
        componentIds[type] = 1 unless componentIds[type]?
        componentIds[type] = componentIds[type] + 1 while $("[data-component-id='#{type}-#{componentIds[type]}']",
          spi.composer).length != 0
        "#{type}-#{componentIds[type]}"
      load: (component_config) ->
        for key, value of component_config
          componentIds[value.type] = 1 unless componentIds[value.type]?
          id = parseInt(key.replace(/.*-/,''))
          componentIds[value.type] = switch
            when id == componentIds[value.type] then id + 1
            when id > componentIds[value.type] then id
    )()

    newComponent = (component, id, type, config) ->
      component.data('component-config', config).attr('data-role', 'component').attr('data-component-type', type)
      .attr('data-component-id', id)

    createComponentEditor = (target, name, id, config, content) ->
      newComponent(ComponentEditor.create(target, components[name], config, content), id, name, config)
    createComponentControl = (target, name, id, config, content) ->
      newComponent(components[name].control(target, config, content), id, name, config).data('component-content', content)
    createPlaceHolder = (target, name, id, config, content) ->
      placeholder = if components[name].placeholder? then components[name].placeholder(target) else $('<div></div>')
      newComponent(placeholder, id, name, config).data('component-content', content)

    createComponent = (components, creator, target) ->
      components().map(-> $(this).data('component-id')).each (index, id)->
        component = $("[data-component-id='#{id}']", target)
        component.replaceWith(creator(component, component.data('component-type'), id,
          ComponentEditor.getConfiguration(component), ComponentEditor.getContent(component)))
    destroyComponent = (destroy) ->
      spi.components().each ->
        component = $(this)
        type = components[component.data('component-type')]
        return $.error("no such component #{component.data('component-type')}") unless type
        type[destroy](component) if type[destroy]

    extensionPoints: ->
      spi.installComponent = (name, component) -> components[name] = component
      spi.insertComponent = (target, name, config = {}, content = {}) ->
        return $.error("no such component #{name}") unless components[name]
        return $.error("components can only be created in edit mode") unless api.mode() == 'edit'
        target.append(createComponentEditor(null, name, IdGenerator.next(name), config, $.extend({}, components[name].dataTemplate, content)))

      spi.toEditor = (target) ->
        createComponent(->
          $('*[data-role="component"]', target)
        , createComponentEditor, target)
      spi.toControl = (target) ->
        createComponent(->
          $('*[data-role="component"][data-component-type!="page"]', target)
        , createComponentControl, target)
      spi.toPlaceholder = (target) ->
        createComponent(->
          $('*[data-role="component"]', target)
        , createPlaceHolder, target)

      spi.getPlaceholder = (component) ->
        createPlaceHolder(component, component.data('component-type'), component.data('component-id'),
          ComponentEditor.getConfiguration(component), ComponentEditor.getContent(component))

      spi.getComponentContent = (component) -> ComponentEditor.getContent(component)
      spi.loadGenerator = (config) -> IdGenerator.load(config)
      spi.components = (target = spi.composer)-> $('*[data-role="component"]', target)

      api.insertComponent = (name, config = {}, content) -> spi.insertComponent(spi.composer, name, config, content)

      api.getComponentConfiguration = (component) -> ComponentEditor.getConfiguration(component)
      api.setComponentConfiguration = (component, value) -> ComponentEditor.setConfiguration(component, value)

    extensions: ->
      spi.mode 'edit',
        on:  -> spi.toEditor(spi.composer)
        off:  -> destroyComponent('destroyEditor')
      spi.mode 'preview',
        on: -> spi.toControl(spi.composer)
        off: -> destroyComponent('destroyControl')

  $.fn.honegger.defaults.plugins.push(ContentComponent)
  $.fn.honegger.defaults.defaultMode = 'edit'
)(jQuery)
