# TODO: Comment
module Jekyll
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
                    context['active_vignette'][:competencies].push({
                        'id': competency['id'],
                        'count': 1
                    })
                end
            end

            # Render if available.
            if competency
                "<span class=\"a-pill\">#{competency['id']}</span>"
            else
                "<span class=\"a-pill a-pill--error\">\"#{@competencyId}\" undefined</span>"
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
            classString = 'o-vignette-blocks__block'
            if context['page']['vignettes'].size == 1
                classString += ' o-vignette-blocks__block--active'
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