module Jekyll
  module LiquidFilter
    def liquidify(input)
      # 1. Access the global site data (everything in _config.yml)
      setup = @context.registers[:site]
      
      # 2. Convert the "plain text" from your front matter into a Liquid template
      template = Liquid::Template.parse(input)
      
      # 3. Render that template using the site's variables and return the result
      template.render(setup.site_payload)
    end
  end
end

# 4. Tell Jekyll this filter is called 'liquidify'
Liquid::Template.register_filter(Jekyll::LiquidFilter)
