module Jekyll
  class LlmsGenerator < Generator
    safe true
    priority :low

    def generate(site)
      site_url = site.config['url'] || ""
      
      # 1. Initialize Content
      summary_content = "# #{site.config['title']}\n"
      summary_content << "> #{site.config['description']}\n\n"
      
      full_content = "# Full Index: #{site.config['title']}\n\n"

      # 2. Collect and Filter Documents
      all_docs = (site.pages + site.posts.docs).reject do |doc|
        # Exclude: pagination, hidden files, or missing titles
        doc.data['pager'] || 
        doc.url =~ /\/page\d+\/$/ || 
        doc.data['hide_llm'] || 
        doc.data['title'].nil?
      end

      # 3. Group by Category for the Summary File
      grouped = all_docs.group_by { |d| d.data['categories']&.first || "General" }

      grouped.each do |category, docs|
        summary_content << "## #{category.capitalize}\n"
        
        docs.each do |doc|
          abs_url = site_url + doc.url
          title = doc.data['title']
          
          # Clean HTML for Summary (short excerpt)
          raw_summary = doc.data['summary'] || (doc.data['excerpt'] ? doc.data['excerpt'].to_s : "")
          clean_summary = strip_html(raw_summary).strip[0..150].gsub(/\s+/, " ")

          summary_content << "- [#{title}](#{abs_url}): #{clean_summary}\n"

          # Clean HTML for Full Index
          clean_full_body = strip_html(doc.content.to_s).strip
          
          full_content << "## #{title}\n"
          full_content << "URL: #{abs_url}\n"
          full_content << "Category: #{category}\n\n"
          full_content << "#{clean_full_body}\n\n"
          full_content << "---\n\n"
        end
        summary_content << "\n"
      end

      # 4. Link Full Index at the bottom of Summary
      summary_content << "## Full Content\n"
      summary_content << "- [Full Site Index](#{site_url}/llms-full.txt): A complete text dump for deep indexing.\n"

      # 5. Output Files
      site.pages << LlmsStaticPage.new(site, site.source, "/", "llms.txt", summary_content)
      site.pages << LlmsStaticPage.new(site, site.source, "/", "llms-full.txt", full_content)
    end

    private

    def strip_html(input)
      return "" if input.nil?
      input.to_s
           .gsub(/<script.*?<\/script>/m, '') # Remove JS
           .gsub(/<style.*?<\/style>/m, '')   # Remove CSS
           .gsub(/<[^>]*>/, ' ')              # Strip tags
           .gsub(/&nbsp;/, ' ')               # Fix common entities
           .gsub(/\s+/, " ")                  # Normalize whitespace
    end
  end

  class LlmsStaticPage < Page
    def initialize(site, base, dir, name, content)
      @site, @base, @dir, @name = site, base, dir, name
      self.process(name)
      self.data = {}
      self.content = content
    end
  end
end
