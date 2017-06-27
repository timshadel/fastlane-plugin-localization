module Fastlane
  module Actions
    Match = Struct.new("Match", :node, :field, :exp)
    class TrimLocalizationsAction < Action
      def self.run(params)
        Actions.verify_gem!('oga')
        require 'oga'

        path = params[:path]
        items = {
          source: params[:text],
          note: params[:comment]
        }

        UI.success "Trimming localizations in #{path}"

        matches = []
        doc = Oga.parse_xml(File.open(path))
        items.each do |type, values|
          kind = type == :source ? 'text' : 'comment'
          values.each do |e|
            if e.kind_of? String
              doc.css("trans-unit #{type}").select { |n| n.text == e }.each do |node|
                matches << Match.new(node, kind, e)
              end
            elsif e.kind_of? Regexp
              doc.css("trans-unit #{type}").select { |n| n.text =~ e }.each do |node|
                matches << Match.new(node, kind, e.to_s)
              end
            else
              UI.error "Trimming value (#{e}) must be either a string or a regular expression."
            end
          end
        end

        matches.each do |match|
          puts(match) if match.node.nil?
          unit = match.node.parent
          if unit.nil? or unit.parent.nil?
            UI.message "Removing #{unit.attr('id')} because its #{match.field} was '#{match.node.text}'"
            next
          end
          file = unit.parent.parent
          UI.message "Removing #{unit.attr('id')} because its #{match.field} was '#{match.node.text}' (#{file.attr('original')})"
          unit.remove
        end

        File.open(path, 'w') { |file| file.write(doc.to_xml) }

        if matches.count == 1
          UI.success "Trimmed 1 localization"
        else
          UI.success "Trimmed #{matches.count} localizations"
        end
      end

      def self.description
        "Remove localizations from XLIFF files"
      end

      def self.authors
        ["timshadel"]
      end

      def self.available_options
        [
           FastlaneCore::ConfigItem.new(key: :path,
                                description: "XLIFF file to be trimmed",
                                   optional: false,
                                       type: String),
           FastlaneCore::ConfigItem.new(key: :text,
                                description: "Sources that match these strings or expressions will be removed from the XLIFF file",
                                   optional: true,
                                       type: Array),
           FastlaneCore::ConfigItem.new(key: :comment,
                                description: "Notes that match these strings or expressions will be removed from the XLIFF file",
                                   optional: true,
                                       type: Array),
         ]
      end

      def self.is_supported?(platform)
          true
      end
    end
  end
end
