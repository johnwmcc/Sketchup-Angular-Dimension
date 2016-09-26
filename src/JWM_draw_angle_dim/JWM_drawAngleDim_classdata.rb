#
#  Data definitions, accessors, and initializers for the DrawAngleDimTool class
#
module JWMPlugins
  module AngularDim

    class DrawAngleDimTool

      ###################
      # Class constants
      if(Sketchup.version.to_i >= 16)
        if(RUBY_PLATFORM =~ /darwin/)
          #        IN_ICON =  Sketchup.find_support_file('inside.pdf', 'Plugins/JWM_draw_angle_dim/Images') unless defined? IN_ICON
          #        OUT_ICON = Sketchup.find_support_file('outside.pdf', 'Plugins/JWM_draw_angle_dim/Images') unless defined? OUT_ICON
          IN_ICON =  File.join(IMGPATH, 'inside.pdf') unless defined? IN_ICON
          OUT_ICON =  File.join(IMGPATH, 'outside.pdf') unless defined? OUT_ICON
        else
          #        IN_ICON =  Sketchup.find_support_file('inside.svg', 'Plugins/JWM_draw_angle_dim/Images') unless defined? IN_ICON
          #        OUT_ICON = Sketchup.find_support_file('outside.svg', 'Plugins/JWM_draw_angle_dim/Images') unless defined? OUT_ICON
          IN_ICON =  File.join(IMGPATH, 'inside.svg') unless defined? IN_ICON
          OUT_ICON =  File.join(IMGPATH, 'outside.svg') unless defined? OUT_ICON
        end
      else
        #      IN_ICON =  Sketchup.find_support_file('interior2.png', 'Plugins/JWM_draw_angle_dim/Images') unless defined? IN_ICON
        #      OUT_ICON = Sketchup.find_support_file('exterior2.png', 'Plugins/JWM_draw_angle_dim/Images') unless defined? OUT_ICON
        IN_ICON =  File.join(IMGPATH, 'interior2.f') unless defined? IN_ICON
        OUT_ICON =  File.join(IMGPATH, 'exterior2.png') unless defined? OUT_ICON
      end

      IN_CURSOR = UI::create_cursor(IN_ICON, 0, 31) unless defined? IN_CURSOR
      OUT_CURSOR = UI::create_cursor(OUT_ICON, 0, 31) unless defined? OUT_CURSOR

      #################################
      # Class singleton variables and methods.  They remember values between invocations
      # of the tool.  CSV's are in some ways similar to @@ variables, in that they
      # belong to the class, not to instances, but are not inherited.  Hence many
      # Ruby experts consider them safer than @@ variables.

      # TODO: add range validations where applicable so these don't break the drawing
      # logic

      # TODO: add means to reset all values to defaults

      # NOTE: Not all of these are used by the code yet.  TODO: eliminate ones that ultimately
      # remain unused.
      DEFAULT_RADIUS = -1.0 unless defined? DEFAULT_RADIUS
      @user_radius = DEFAULT_RADIUS
      def self.user_radius=(radius)
        if radius > 0
          @user_radius = radius
        else
          @user_radius = DEFAULT_RADIUS
        end
      end
      def self.user_radius
        @user_radius
      end
      DEFAULT_TEXT_HEIGHT = -1.0 unless defined? DEFAULT_TEXT_HEIGHT
      @user_text_height = DEFAULT_TEXT_HEIGHT 
      def self.user_text_height=(height)
        if height > 0
          @user_text_height = height
        else
          @user_text_height = DEFAULT_TEXT_HEIGHT
        end
      end
      def self.user_text_height
        @user_text_height
      end
      DEFAULT_LINE_SCALE = 1.05 unless defined? DEFAULT_LINE_SCALE
      @dim_line_scale = DEFAULT_LINE_SCALE
      def self.dim_line_scale=(scale)
        @dim_line_scale = scale
      end
      def self.dim_line_scale
        @dim_line_scale
      end
      DEFAULT_ARROW_SCALE = 0.05 unless defined? DEFAULT_ARROW_SCALE
      @arrow_scale = DEFAULT_ARROW_SCALE
      def self.arrow_scale=(scale)
        @arrow_scale = scale
      end
      def self.arrow_scale
        @arrow_scale
      end
      DEFAULT_ARC_SEGMENTS = 12 unless defined? DEFAULT_ARC_SEGMENTS
      @arc_segments = DEFAULT_ARC_SEGMENTS
      def self.arc_segments=(segs)
        @arc_segments = segs
      end
      def self.arc_segments
        @arc_segments
      end
      DEFAULT_ARROW_STYLE = 'open' unless defined? DEFAULT_ARROW_STYLE
      @arrow_style = DEFAULT_ARROW_STYLE
      def self.arrow_style=(style)
        @arrow_style = style
      end
      def self.arrow_style
        @arrow_style
      end

      # TODO: decide on a UI to invoke this.
      def self.reset_defaults
        @user_radius = DEFAULT_USER_RADIUS
        @user_text_height = DEFAULT_TEXT_HEIGHT
        @dim_line_scale = DEFAULT_LINE_SCALE
        @arrow_scale = DEFAULT_ARROW_SCALE
        @arc_segments = DEFAULT_ARC_SEGMENTS
        @arrow_style = DEFAULT_ARROW_STYLE
      end

      #---------------------------------
      # Get new values of user-settable parameters via a UI.inputbox.  The values
      # are remembered in class instance variables so that they persist when a
      # Tool instance is deactivated.
      
      # Return value is true if any of the parameters were changed by user.
      
      # TODO: add range checks either here or in the '=' methods above.
      # The UI.inputbox will test whether the user's entries are the right
      # type, e.g. string, float, int, but not whether they are acceptable values.

      # TBD: user radius isn't included here yet because it can be input via the
      # VCB, which is easier.  Should it also be here?
      
      def self.user_params_input
        # inputbox argument arrays.
        # TODO: remove items that ultimately are not used by the drawing logic
        
        begin # exception rescue block in case of bad input by user
          prompts = ['Arrow Style','Text Height', 'Line Scale', 'Arrow Scale', 'Arc Segments']
          defaults = [@arrow_style,
                      @user_text_height.to_s,
                      @dim_line_scale,
                      @arrow_scale,
                      @arc_segments]
          list = ['open|closed|slash|dot|none', "", "", "", ""]

          inputs = UI.inputbox(prompts, defaults, list, "Angular Dimension Settings")
          puts "got inputs #{inputs}"
          
          changed = false

          if inputs != false
            puts "processing inputs"
            if inputs[0] != @arrow_style
              @arrow_style = inputs[0]
              changed = true
            end
            if inputs[1] != @user_text_height
              @user_text_height = inputs[1].to_l
              changed = true
            end
            if inputs[2] != @dim_line_scale
              @dim_line_scale = inputs[2]
              changed = true
            end
            if inputs[3] != @arrow_scale
              @arrow_scale = inputs[3]
              changed = true
            end
            if inputs[4] != @arc_segments
              @arc_segments = inputs[4]
              changed = true
            end
          end
        rescue Exception => e
          UI.messagebox("bad input value: #{e.message}")
          retry
        end
        changed
      end


    end # DrawAngleDimTool
  end # AngularDim
end # JWMPlugins
