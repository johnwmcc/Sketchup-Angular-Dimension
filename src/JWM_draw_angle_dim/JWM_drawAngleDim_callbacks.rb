#
# SketchUp tool callbacks for DrawAngleDimTool
#
# This separates the methods of the Tool protocol from the drawing logic of
# the class.
#

module JWMPlugins
  module AngularDim

    class DrawAngleDimTool

      #-----------------------------------------------------------------------------
      def activate
        reset
      end
      #-----------------------------------------------------------------------------
      def deactivate(view)
        reset
        view.invalidate if @drawn
      end
      #-----------------------------------------------------------------------------
      # need this to cause inference point and tooltips to be drawn
      def onMouseMove(flags, x, y, view)
        @ip.pick(view, x, y, @ip1)
        view.invalidate
        nil
      end
           #-----------------------------------------------------------------------------
      # user clicks the mouse button - capture the data point and advance the state
      def onLButtonDown(flags, x, y, view)
        set_current_point(x, y, view)
        increment_state
        nil
      end

      #-----------------------------------------------------------------------------
      # Because of the context-menu system, this will get called only if a right-click
      # is on empty space.  That makes its usefulness very limited!
#      def onRButtonDown(flags, x, y, view)
#        puts "onRButtonDown"
#      end
      
      #-----------------------------------------------------------------------------
      # This is called when the user right-clicks on any entity when the tool is active.
      # SketchUp intercepts such clicks and triggers its context menu system because maybe
      # the user wanted to do something such as explode rather than alter the AD parameters;
      # the right-click event is passed through to onRButtonDown or onRButtonUp only if you click on nothing!
      # As done here, this results in a two-step operation to set parameters: right-click
      # to get a menu, then click the menu to get an inputbox.
      #
      #  NOTE: The version below works only on SU >= 2015 because it uses the x, y, and view parameters
      # that were not present in earlier versions
      
      # TODO: decide between this technique and the onKeyDown variation below, or find an even better way.
      # Each method I have tried has at least some awkwardness...

      # def getMenu(menu, flags, x, y, view)
      #   # puts "Context menu triggered.  Menu = #{menu}"
      #   menu.add_item("Angular Dimension Parameters") {
      #     # determine what the user clicked on
      #     ph = view.pick_helper
      #     num = ph.do_pick(x,y)
      #     puts "#{num} picked"
      #     if num > 0
      #       picked = ph.best_picked
      #       puts "picked #{picked}"
      #       # If selected object is an Angular Dimension group, then popup Inputbox for editing settings
      #       if picked.is_a?(Sketchup::Group) && picked.name =~ /Angular Dimension.*/
      #         puts "picked is an existing AD"
      #         changed = self.class.user_params_input
      #         puts "changed = #{changed}"
              
      #         # redraw using new params, if appropriate
      #         # If invoked immediately after drawing an AD, this will redraw it using the
      #         # new style.  Otherwise it will only set the new style for the next AD.
      #         # TODO: Make this operate on the AD you clicked, not the last drawn!
      #         # That will require regenerating the parameters of the existing AD from
      #         # the group, erasing the group, then starting over.
      #         if changed && @drawn
      #           puts "doing a redraw"
      #           # undo the previous operation before redrawing
      #           # this avoids buildup of obsolete operations on the
      #           # undo stack
      #           Sketchup.undo if @state==0
      #           draw_angle_dim
      #         else
      #           puts "not just drawn, no redraw"
      #         end    
      #       else
      #         puts "not an existing AD"
      #       end
      #     else
      #       puts "Click was not on anything"
      #     end
      #   }
      # end
      #-----------------------------------------------------------------------------
      def onCancel(flag, view)
        view.invalidate if @drawn
        reset
      end
      #-----------------------------------------------------------------------------
      # Tell SketchUp that this Tool accepts user input via the VCB
      # Contrary to what the API docs say, SketchUp assumes a Tool will accept VCB
      # input by default and this method has no detectable effect!  Included here
      # in case the someday fix this bug.
      def enableVCB?
        true
      end
      #-----------------------------------------------------------------------------

      # accept user input in the VCB as the desired radius of the dimension arc
      def onUserText(text, view)
        puts "onUserText"
        # The user may type in something that we can't parse as a length
        # so we set up some exception handling to trap that
        begin
          value = text.to_l
        rescue
          # Error parsing the text
          UI.messagebox("please enter a number for arc radius")
          value = nil
          Sketchup::set_status_text "", SB_VCB_VALUE
        end
        if(value <= 0.0)
          UI.messagebox("arc radius must be a positive number")
          value = nil
          Sketchup::set_status_text "", SB_VCB_VALUE
        end
        return if !value

        self.class.user_radius = value

        # redraw at new radius, if appropriate
        if @drawn
          # undo the previous operation before redrawing
          # this avoids buildup of obsolete operations on the
          # undo stack
          Sketchup.undo if @state==0
          draw_angle_dim
        end
        nil
      end
      #-----------------------------------------------------------------------------
      # invoked by SketchUp when the view is invalidated.
      def draw(view)
        # make sure the input point's tooltip is displayed
        view.tooltip = @ip.tooltip
        @ip.draw view

        # provide visual feedback of what's been clicked.
        # note: SketchUp "forgets" the lines whenever the
        # view is invalidated.  They must be redrawn every
        # time or they will vanish.  That also means there is
        # no need to erase them afterward.
        case @state
        when 1
          # first point selected,
          # draw "rubber band" to cursor from first point
          view.drawing_color = "magenta"
          view.line_width = 2
          view.draw(GL_LINE_STRIP,  @pts[0], @ip.position)          
        when 2
          # first and second points selected,
          # draw line between first two points and "rubber band" from second to cursor
          view.drawing_color = "magenta"
          view.line_width = 2
          view.draw(GL_LINE_STRIP, @pts[0], @pts[1])
          view.draw(GL_LINE_STRIP, @pts[1], @ip.position)
        end
        nil
      end
      #-----------------------------------------------------------------------------
      def onSetCursor
        UI::set_cursor(@cursor)
      end
      #-----------------------------------------------------------------------------
      # Toggle the drawing mode when the user presses TAB
      # on a PC or ALT on a Mac.  It is necessary to use
      # different keys per system because TAB on Mac and
      # ALT on PC are captured by the system to select
      # menu items and the keypress event never reaches here!
      #
      # Present the parameter selection menu if the user presses CTRL key.
      # TODO: reconsider this trigger.  Ctrl on Windows is chorded with
      # too many other keys, e.g. ctrl-a to select all, and we are likely to
      # cause confusing interference!
      #
      # TODO: Submit a bug report and find a workaround for the following:
      # When a UI.inputbox is opened within this callback (as is done in
      # the user_input_params method), SU does not return keyboard focus
      # to the Tool when the inputbox closes.  As a result, the next
      # keypress is lost.  Double-tapping ctrl, alt, or tab gets the
      # handler to work, but that's a bad UI!
      def onKeyDown(key, rpt, flags, view)
        puts "onKeyDown #{key}, rpt=#{rpt}, flags=#{flags}, view=#{view}"

        # platform sensitive mode toggle key
        # Alt on PC and Tab on Mac are hard-wired to system-specific uses,
        # that preempt this event callback, so can't use either cross-platform.
        if(RUBY_PLATFORM =~ /darwin/)
          keycode = VK_ALT
        else
          # no virtual key code for tab on Windows?, so hard wired!
          keycode = 9
        end

        case key
        when VK_CONTROL
          # control key to fetch new parameters via inputbox.  This is the alternative to
          # the context menu technique above.
          changed = self.class.user_params_input
          puts "changed = #{changed}"
          
          # redraw using new params, if appropriate
          # If invoked immediately after drawing an AD, this will redraw it using the
          # new style.  Otherwise it will only set the new style for the next AD.
          # TODO: Make this operate on the AD you clicked, not the last drawn!
          # That will require regenerating the parameters of the existing AD from
          # the group, erasing the group, then starting over.
          if changed && @drawn
            puts "doing a redraw"
            # undo the previous operation before redrawing
            # this avoids buildup of obsolete operations on the
            # undo stack
            Sketchup.undo if @state==0
            draw_angle_dim
          else
            puts "not just drawn, no redraw"
          end
        when keycode
          # inside vs outside toggle
          @inside = !@inside
          if @inside
            @cursor = IN_CURSOR
          else
            @cursor = OUT_CURSOR
          end
          UI.set_cursor(@cursor)

          # redraw in new mode if appropriate
          if @drawn
            # undo the previous operation before redrawing
            # this avoids buildup of unneeded operations on
            # the undo stack
            Sketchup.undo if @state==0
            draw_angle_dim
          end
        end
        nil
      end # onKeyDown
      #-----------------------------------------------------------------------------
      # def onKeyUp(key, rpt, flags, view)
      # end

    end # DrawAngleDimTool
  end # AngularDim
end # JWMPlugins
