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
            # Edge case - work around to prevent excerpt rendering from producing extra page meta.
            if caller.any? { |trace| trace.include? 'jekyll/excerpt' }
                return
            end

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
            def include_fields_from_document(input, fields)
                filter_fields_from_document(input, fields, false)
            end

            def strip_fields_from_document(input, fields)
                filter_fields_from_document(input, fields, true)
            end

            def filter_fields_from_document(input, fields, exclude)
                downcased_fields = fields
                    .split(",")
                    .map { |field| field.strip.downcase }
            
                temp = {}

                input.map do |entry|
                    if exclude
                        if !downcased_fields.include?(entry.downcase)
                            temp[entry] = input[entry]
                        end
                    else
                        if downcased_fields.include?(entry.downcase)
                            temp[entry] = input[entry]
                        end
                    end
                end

                temp
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
        def initialize(site, base, dir, name, template, data=nil)
            @site = site
            @base = base
            @dir = dir
            @name = name

            self.process(@name)
            self.read_yaml(template, @name)
            
            if data
                self.data["payload"] = data
            end
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

                data = {}

                # If there is a specific payload that needs to be sent...
                if basename == "progression.json" || basename == "progression.html" 
                    data = build_progression_payload(site)
                end
 
                site.pages << GeneratedPage.new(
                    site,
                    site.source,
                    outDirectory,
                    basename,
                    filePath.sub(basename, ''),
                    data
                )           
            end
        end

        def build_progression_payload(site)
            categories = site.data['competencies'].group_by {|c| c['categories'][0]}
            num_competencies = site.data['competencies'].size
            
            a_projects = site.data['projects']
            u_vignettes = site.posts.docs.select {|p| p['type'] == 'vignette'}

            project_rows = []

            for a_project in a_projects
                project_row = {}

                # Set project meta.
                project_row['projectId'] = a_project['id']
                project_row['projectTitle'] = a_project['title']
                project_row['deadline'] = a_project['deadline']

                # Find related user-submitted post.
                linked_vignettes = u_vignettes.select {|v| v.data['project_code'] == a_project['id']}
                project_row['submitted'] = linked_vignettes.size > 0

                # There should only be one...
                vignette = linked_vignettes[0]
                
                if project_row['submitted']
                    # Generators run before 'render', so it is necessary to
                    # render this document early to access meta-information
                    # computed from tags during.
                    Jekyll::Renderer.new(site, vignette, site.site_payload).run
                    # It now has 'data' Hash.
                end

                # Compute values for each competency.
                project_row['competencies'] = []

                num_targets_met = 0

                # Iterate over competencies.
                for category in categories
                    for competency in category[1]
                        computed_competency = {}

                        computed_competency['competencyId'] = competency['id']
                        
                        # Find out if it was a target of the project.
                        computed_competency['target'] = a_project['targets'].include? competency['id']

                        # Find out if it was included in the user's final vignette iteration.
                        if project_row['submitted']
                            final_vignette = vignette.data['vignettes'].last
                            computed_competency['included'] = final_vignette[:competencies].any? {|c| c[:id] == competency['id']}
                        else
                            computed_competency['included'] = false
                        end

                        # If it was a target that was met
                        if computed_competency['target'] && computed_competency['included']
                            num_targets_met += 1
                        end

                        project_row['competencies'].push(computed_competency)
                    end
                end

                project_row['allTargetsHit'] = num_targets_met == a_project['targets'].size

                project_rows.push(project_row)
            end

            return {
                "project_rows" => project_rows,
                "categories" => categories,
                "num_competencies" => num_competencies
            }
        end
    end
end

# Register everything.
Liquid::Template.register_tag('c', Jekyll::CompetencyTag)
Liquid::Template.register_tag('competency', Jekyll::CompetencyTag)

Liquid::Template.register_tag('v', Jekyll::VignetteTag)
Liquid::Template.register_tag('vignette', Jekyll::VignetteTag)

Liquid::Template.register_filter(Jekyll::Filters::ApiFilter)