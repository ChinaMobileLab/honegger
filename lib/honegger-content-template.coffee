(($) ->
  ContentTemplate = (api, spi) ->
    extensionPoints: ->
      api.getContentTemplate = ->
        composer = spi.composer.clone()
        config = {}
        content = {}

        spi.components(composer).each ->
          component = $(this)
          config[component.data('component-id')] = $.extend({}, spi.getComponentConfiguration(component),
            type: component.data('component-type'))
          content[component.data('component-id')] = $.extend({}, spi.getComponentContent(component),
            type: component.data('component-type'))

        spi.components(composer).each ->
          component = $(this)
          return if component.parents('*[data-role="component"]').length != 0
          component.replaceWith(spi.getPlaceholder($(this))[0].outerHTML)

        template: composer.html()
        config: config
        content: content

      api.loadContentTemplate = (template, config, content, mode) ->
        spi.composer.html(template)
        $.each config, (key, value)-> $("[data-component-id='#{key}']", spi.composer).data('component-config', value)
        $.each content, (key, value)->
          value.content = $('<div/>').html(value.content).text() if value.content
          $("[data-component-id='#{key}']", spi.composer).data('component-content', value)
        api.changeMode(mode)
        spi.composer.trigger('honegger.syncPages')

  $.fn.honegger.defaults.plugins.push(ContentTemplate)
)(jQuery)