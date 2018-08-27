# TODO: Comment!
module Jekyll
    # Define custom commands.
    module Commands
        class NewProject < Command
            def self.init_with_program(prog)
                prog.command(:project) do |c|
                    # Define documentation.
                    c.syntax 'project NAME'
                    c.description 'Creates a new project with the given NAME'
        
                    # Define options.
                    c.option 'date', '-d DATE', '--date DATE', 'Specify the post date'
                    c.option 'force', '-f', '--force', 'Overwrite a post if it already exists'
        
                    # Process.
                    c.action do |args, options|
                        Jekyll::Commands::NewProject.process(args, options)
                    end
                end
            end

            def self.process(args, options = {})
                # Null check required fields.
                raise ArgumentError.new('You must specify a project name.') if args.empty?
                
                # Create default options for each post type.
                ext = "md"
                date = options["date"].nil? ? Time.now : DateTime.parse(options["date"])

                title = args.shift
                name = title.gsub(' ', '-').downcase

                # Fill task from data file.
                post_types_data_file = "project-post-types"
                
                # Initialise the site object from configuration (to access data files)
                config_options = configuration_from_options({})
                site = Jekyll::Site.new(config_options)
                site.read

                post_types = site.site_data[post_types_data_file]

                if post_types.size > 0
                    # Make subdirectory.
                    FileUtils.mkdir_p directory_name(name, date)
                else
                    raise RangeError.new("There are no post types defined in #{post_types_data_file}.")
                end
                
                # For every post-type in subfolder...
                post_types.each do |post_type|
                    # Format file path.
                    post_path = file_name(name, post_type['post_type'], ext, date)

                    raise ArgumentError.new("A post already exists at ./#{post_path}") if File.exist?(post_path) and !options["force"]
                    
                    # Create file.
                    IO.copy_stream("_layouts/examples/#{post_type['template_file']}", post_path)
                    
                    # File.open(post_path, "w") do |f|
                    #     # Fill it with appropriate front-matter.
                    #     f.puts(front_matter(post_type[:post_type], title))
                    # end
                end

                puts "New posts created at ./_posts/#{date.strftime('%Y-%m-%d')}-#{name}.\n"
            end 
            
            def self.directory_name(name, date)
                "_posts/#{date.strftime('%Y-%m-%d')}-#{name}"
            end

            # Returns the filename of the draft, as a String
            def self.file_name(name, post_type, ext, date)
                "_posts/#{date.strftime('%Y-%m-%d')}-#{name}/#{post_type}.#{ext}"
            end

            # TODO: Replace this with smart filling from data file and template file.
            def self.front_matter(layout, title)
                "---
                layout: #{layout}
                title: #{title}
                ---"
            end
        end
    end

    class ProjectGenerator < Generator
        safe true
        priority :highest
        
        def generate(site)
            # Select and group posts by subdirectory
            postsByProject = site.posts.docs.group_by { |post| post.id[/.*(?=\/)/] }

            # Iterate over groupings
            postsByProject.each do |grouping|
                projectId = grouping[0]
                projectFiles = grouping[1]

                projectUrls = {}

                # Give each file one-off values and assess availability.
                projectFiles.each do |file|
                    # Give each the project Id
                    file.data['project_id'] = projectId
                    # Give each the project title
                    file.data['project_title'] = file.data['title'][/.*(?=\/)/]
                    # Give each a type
                    file.data['type'] = file.basename_without_ext

                    projectUrls[file.data['type']] = file.url
                end

                # Add singling URLs based on type.
                projectFiles.each do |file|
                    file.data['project_urls'] = projectUrls
                end
            end
        end
    end

    class CompetencyTag < Liquid::Tag
        def initialize(tag_name, text, tokens)
            super

            # Store competency id for later.
            @competencyId = text.strip.split(" ")[0]
        end
    
        def render(context)
            # Find the correct competency.
            competency = context.registers[:site].data['competencies'].select {|c| c['id'] == @competencyId} [0]
            
            # Add it to vignette if one exists.
            if context['active_vignette']
                # Find out if the current competency has already been logged.
                competencyTally = context['active_vignette'][:competencies].select {|c| c[:id] == competency['id']} [0]

                if competencyTally
                    # Increment tally.
                    competencyTally[:count] += 1
                else
                    # Add entry.
                    if competency
                        context['active_vignette'][:competencies].push({
                            'id': competency['id'],
                            'count': 1,
                            'linked': true
                        })
                    else
                        context['active_vignette'][:competencies].push({
                            'id': @competencyId,
                            'count': 1,
                            'linked': false
                        })
                    end
                end
            end

            # Render if available.
            if competency
                # <a href="#" class="badge badge-primary">Primary</a>
                " <a href=\"#{context.registers[:site].baseurl}/competencies##{competency['id']}\" class=\"badge badge-primary\">#{competency['id']}</a>"
            else
                " <span class=\"badge badge-danger\">#{@competencyId} undefined</span>"
            end
        end
    end

    class VignetteTag < Liquid::Block
        def initialize(tag_name, markup, tokens)
            super
        end
      
        def render(context)
            # Check for existence of vignette iterations.
            if !context['page']['vignettes']
                context['page']['vignettes'] = []

                # Check for project data.
                if context['page']['project_code']
                    project = context.registers[:site].data['projects'].select {|p| p['id'] == context['page']['project_code']} [0]
                    
                    # Add target competencies.
                    if project
                        context['page']['targets'] = project['targets']
                    end
                end
            end

            # Create a new iteration.
            context['active_vignette'] = {
                'competencies': []
            }

            # Add it to the array.
            context['page']['vignettes'].push(context['active_vignette'])

            # Render text as normal.
            rendered = super
            # Wrap in page-specific markup.
            classString = 'vignette-block'
            if context['page']['vignettes'].size == 1
                classString += ' active'
            end
            "<div class=\"#{classString}\" id=\"block-#{context['page']['vignettes'].size - 1}\">#{rendered}</div>"
        end
    end

    module Filters
        module ApiFilter
            def flatten_hash(input)
                all_values = input.to_a.flatten
                hash_values = all_values.select { |value| value.class == Hash }
                most_nested_values = []
        
                if hash_values.count > 0
                  hash_values.each do |hash_value|
                    most_nested_values << flatten_hash(hash_value)
                  end
        
                  most_nested_values.flatten
                else
                  return input
                end
              end
            def filter_fields(input, fields)
                downcased_fields = fields
                    .split(",")
                    .map { |field| field.strip.downcase }
    
                input.map do |entry|
                    entry.select do |key, value|
                        downcased_fields.include?(key.downcase)
                    end
                end
            end
        end
    end
end

# Register everything.
Liquid::Template.register_tag('c', Jekyll::CompetencyTag)
Liquid::Template.register_tag('competency', Jekyll::CompetencyTag)

Liquid::Template.register_tag('v', Jekyll::VignetteTag)
Liquid::Template.register_tag('vignette', Jekyll::VignetteTag)

Liquid::Template.register_filter(Jekyll::Filters::ApiFilter)