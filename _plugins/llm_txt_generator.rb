module Jekyll
  class LlmsGenerator < Generator
    safe true
    priority :low

    def generate(site)
      site_url = site.config['url'] || ""
      
      # 1. Generate llms.txt (The Curated Index)
      summary_content = "# #{site.config['title']}\n"
      summary_content << "> #{site.config['description']}\n\n"
      summary_content << "## Main Resources\n"
      
      # 2. Generate llms-full.txt (The Complete Content)
      full_content = "# Full Index: #{site.config['title']}\n\n"

      # Process Pages and Posts
      all_docs = site.pages + site.posts.docs
      all_docs.each do |doc|
        # Skip documents without a title or those explicitly hidden
        next unless doc.data['title'] && !doc.data['hide_llm']
        
        abs_url = site_url + doc.url
        title = doc.data['title']
        
        # Safely get summary: use front matter 'summary', 
        # or fall back to excerpt, or default to empty string
        summary = doc.data['summary'] || (doc.data['excerpt'] ? doc.data['excerpt'].to_s.strip[0..150] : "")

        # Add to summary file
        summary_content << "- [#{title}](#{abs_url}): #{summary}\n"

        # Fix: Safely handle nil content for llms-full.txt
        raw_content = doc.content.to_s.strip
        
        full_content << "## #{title}\n"
        full_content << "URL: #{abs_url}\n\n"
        full_content << "#{raw_content}\n\n"
        full_content << "---\n\n"
      end

      # Link llms-full.txt at the bottom of llms.txt as per 2026 standards
      summary_content << "\n## Full Content\n"
      summary_content << "- [Full Site Index](#{site_url}/llms-full.txt): A complete text dump for deep indexing.\n"

      # Write files to the site object
      site.pages << LlmsStaticPage.new(site, site.source, "/", "llms.txt", summary_content)
      site.pages << LlmsStaticPage.new(site, site.source, "/", "llms-full.txt", full_content)
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
