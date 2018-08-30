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
                end

                puts "New posts created at ./_posts/#{date.strftime('%Y-%m-%d')}-#{name}.\n"
            end 
            
            def self.directory_name(name, date)
                "_posts/#{date.strftime('%Y-%m-%d')}-#{name}"
            end

            def self.file_name(name, post_type, ext, date)
                "_posts/#{date.strftime('%Y-%m-%d')}-#{name}/#{post_type}.#{ext}"
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
                projectCode = -1

                # Give each file one-off values and assess availability.
                projectFiles.each do |file|
                    # Give each the project Id
                    file.data['project_id'] = projectId
                    # Give each the project title
                    file.data['project_title'] = file.data['title'][/.*(?=\/)/]
                    # Give each a type
                    file.data['type'] = file.basename_without_ext

                    if !file.data['project_code'].nil?
                        projectCode = file.data['project_code']
                    end

                    projectUrls[file.data['type']] = file.url
                end

                # Add singling URLs based on type.
                projectFiles.each do |file|
                    file.data['project_urls'] = projectUrls
                    file.data['project_code'] = projectCode
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

                puts "all_values = #{all_values.inspect}"

                hash_values = all_values.select { |value| value.class == Hash }

                puts "hash_values = #{hash_values.inspect}"

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

            def include_fields(input, fields)
                filter_fields(input, fields, false)
            end

            def strip_fields(input, fields)
                filter_fields(input, fields, true)
            end

            def filter_fields(input, fields, exclude)
                downcased_fields = fields
                    .split(",")
                    .map { |field| field.strip.downcase }
    
                input.map do |entry|
                    puts entry.inspect
                    entry.select do |key, value|
                        if exclude
                            !downcased_fields.include?(key.downcase)
                        else
                            downcased_fields.include?(key.downcase)
                        end
                    end
                end
            end

            def wrap_with_key(input, key)
                {
                    key => input,
                    :status => "OK",
                    :last_updated => Date.today
                }
            end
        end
    end

    class GeneratedPage < Page
        def initialize(site, base, dir, name, template)
            @site = site
            @base = base
            @dir = dir
            @name = name
            self.process(@name)
            self.read_yaml(template, @name)
        end   
    end
    
    class PageGenerator < Generator
        priority :normal

        def generate(site)
            pagesToGenerate = Dir.glob(File.join(site.source, '_layouts/generate/**/*.*'))
            generateBasePath = File.join(site.source, '_layouts/generate')

            pagesToGenerate.each do |filePath|
                basename = File.basename(filePath)
                
                outDirectory = filePath.sub(generateBasePath, '').sub(basename, '')

                site.pages << GeneratedPage.new(
                    site,
                    site.source,
                    outDirectory,
                    basename,
                    filePath.sub(basename, '')
                )           
            end
        end
    end

    class ProgressionPage < Page
        def initialize(site, base, dir, data)
            @site = site
            @base = base
            @dir = dir
            @name = 'progression.html'
            self.process(@name)
            self.read_yaml(File.join(base, '_layouts'), 'progression.html')

            # Format data for API.
            self.data['progression_data'] = data
        end   
    end

    class ProgressionAPIPage < Page
        def initialize(site, base, dir, data)
            @site = site
            @base = base
            @dir = dir
            @name = 'progression.json'
            self.process(@name)
            self.read_yaml(File.join(base, '_layouts'), 'progression.json')

            # Format data for API.
            self.data['progression_data'] = data
        end   
    end
    
    class ProgressionAPIGenerator < Generator
        priority :low

        def generate(site)
            # Format data for API.
            progression_data = build_progression()

            progressionAPIPage = ProgressionAPIPage.new(site, site.source, '/api/v1/', progression_data)
            progressionAPIPage.render(site.layouts, site.site_payload)
            progressionAPIPage.write(site.dest)
            site.pages << progressionAPIPage
            
            progressionPage = ProgressionPage.new(site, site.source, '/', progression_data)
            progressionPage.render(site.layouts, site.site_payload)
            progressionPage.write(site.dest)
            site.pages << progressionPage
        end

        # Internal
        def build_progression()
            return "{\"foo\": \"bar\"}"
        end
    end
end

# Register everything.
Liquid::Template.register_tag('c', Jekyll::CompetencyTag)
Liquid::Template.register_tag('competency', Jekyll::CompetencyTag)

Liquid::Template.register_tag('v', Jekyll::VignetteTag)
Liquid::Template.register_tag('vignette', Jekyll::VignetteTag)

Liquid::Template.register_filter(Jekyll::Filters::ApiFilter)