module Jekyll
  class FileReadTag < Liquid::Tag
    @@cache = {}

    def initialize(tag_name, text, tokens)
      super
      @file_path = text.strip
    end

    def render(context)
      # Check cache first
      return @@cache[@file_path] if @@cache.key?(@file_path)

      # Build the full file path relative to the Jekyll site's root directory
      file_path = File.join(Dir.pwd, @file_path)

      if File.exist?(file_path)
        # Read the content of the file
        content = File.read(file_path)

        # If the file contains YAML front matter (i.e., starts with '---'), parse it
        if content.start_with?('---')
          front_matter_end_index = content.index('---', 3) # Get end of YAML front matter
          if front_matter_end_index
            front_matter = content[3..front_matter_end_index-1] # Extract YAML
            body_content = content[(front_matter_end_index + 3)..] # Extract content after YAML front matter

            # Parse the YAML front matter into a hash
            front_matter_hash = YAML.load(front_matter)

            # Merge the front matter hash into the context (so we can access it in Liquid)
            context['front_matter'] = front_matter_hash
          end
        else
          body_content = content
        end

        # Manually parse and render the content with the Liquid context
        template = Liquid::Template.parse(body_content)
        expanded_content = template.render(context)

        # Cache the result
        @@cache[@file_path] = expanded_content

        # Return the expanded content
        expanded_content
      else
        "Error: File not found."
      end
    end
  end
end

# Register the tag with Jekyll
Liquid::Template.register_tag('file_read', Jekyll::FileReadTag)
