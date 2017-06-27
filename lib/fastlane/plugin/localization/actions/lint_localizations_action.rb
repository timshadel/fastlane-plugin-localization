module Fastlane
  module Actions
    Item = Struct.new("Item", :unit, :type, :role, :note)
    class LintLocalizationsAction < Action
      def self.run(params)
        Actions.verify_gem!('oga')
        require 'oga'

        path = params[:path]
        warn_on_missing = params[:missing_comments] == 'warning'

        UI.success "Linting localizations in #{path}"

        missing = []
        items = []
        doc = Oga.parse_xml(File.open(path))

        # Interface builder strings
        doc.css("trans-unit note").select { |n| n.text =~ /ObjectID/ }.each do |note|
          details = note.text.split(';').map { |i| i.split('=').map {|t| t = t.strip; t = t.gsub(/^\"|\"$/, '') } }
          item = Hash[details]
          type = item["Class"]
          role = details[1][0]
          itemNote = item["Note"]
          unit = note.parent
          if itemNote.nil?
            missing << Item.new(unit, type, role, itemNote)
          else
            items << Item.new(unit, type, role, itemNote)
          end
        end

        missing_count = 0
        missing.each do |item|
          file = item.unit.parent.parent
          if item.note.nil?
            UI.message "Missing translator note for #{item.type}.#{item.role} '#{item.unit.css('source').first.text}' in #{file.get('original')}"
            missing_count += 1
          end
        end

        doc.xpath('//trans-unit[not(note)]').each do |unit|
          file = unit.parent.parent
          UI.message "Missing translator note for '#{unit.get('id')}' in #{file.get('original')}"
          missing_count += 1
        end

        doc.css('trans-unit note').select { |n| n.text == 'No comment provided by engineer.' }.each do |note|
          unit = note.parent
          file = unit.parent.parent
          UI.message "Missing translator note for '#{unit.get('id')}' in #{file.get('original')}"
          missing_count += 1
        end


        if missing_count == 0
          UI.success "No missing comments"
        elsif missing_count == 1
          UI.message "Missing 1 translator comment"
        else
          UI.message "Missing #{missing_count} translator comments"
        end

        items.each do |item|
          desc = "#{item.note} (It appears as a #{self.explain item.role, item.type})"
          note = doc.at_xpath("//trans-unit[@id='#{item.unit.get('id')}']/note/text()")
          note.text = desc
          UI.message desc
        end

        if missing_count == 0 or warn_on_missing
          if items.count > 0
            File.open(path, 'w') { |file| file.write(doc.to_xml) }
            UI.success "Updated translator notes for #{items.count} UI elements"
          end
        end
      end

      def self.explain role, type
        role = "title" if role == "normalTitle"
        role = "description for a blind person" if role == "accessibilityLabel"

        case type
        when "UIButton"
          "#{role} of a button"
        when "UIBarButtonItem"
          "#{role} of a button in a toolbar"
        when "UITabBarItem"
          "#{role} of a tab"
        when "UITextField"
          "#{role} in a field"
        when "UILabel"
          "#{role} in a paragraph on the screen"
        when "UIViewController"
          "#{role} of a screen"
        when "UINavigationItem"
          "#{role} of a screen"
        else
          type
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
                                description: "XLIFF file to be examined",
                                   optional: false,
                                       type: String),
            FastlaneCore::ConfigItem.new(key: :missing_comments,
                                 description: "How to treat missing comments. Options are 'error' and 'warning'. Default is 'error'",
                                        type: String,
                                    optional: true,
                               default_value: 'error',
                                verify_block: proc do |value|
                                   raise "Options are 'error' and 'warning'. Default is 'error'.".red unless value and (value == 'warning' or value == 'error')
                                 end),
       ]
      end

      def self.is_supported?(platform)
          true
      end
    end
  end
end
