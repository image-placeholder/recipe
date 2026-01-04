module Jekyll
  module LiquidFilter
    def liquidify(input)
      return "" if input.nil?
      
      begin
        # Use the site object directly from the registers
        site = @context.registers[:site]
        # Create a new template object
        template = Liquid::Template.parse(input)
        # Render using the existing context to keep variables alive
        template.render(@context)
      rescue StandardError => e
        "Liquidify Error: #{e.message}"
      end
    end
  end
end

Liquid::Template.register_filter(Jekyll::LiquidFilter)
