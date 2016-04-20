# -*- coding: utf-8 -*-
#-----------------------------------------------------------------------------
# Copyright © 2011 Stephen Baumgartner <steve@slbaumgartner.com>
#
# Permission to use, copy, modify, and distribute this software for
# any purpose and without fee is hereby granted, provided the above
# copyright notice appears in all copies.
#
# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#-----------------------------------------------------------------------------
# This was extensively modified and enhanced from dim_angle.rb,
# Copyright 2005, Didier Bur, which, in turn, was based on the demo
# rectangle.rb by @Last Software.
# LanguageHandler added by Mario Chabot 2016. www.formation-sketchup.quebec
#-----------------------------------------------------------------------------
module JWMPlugins

  class DrawAngleDimTool
    if(Sketchup.version.to_i >= 16)
      if(RUBY_PLATFORM =~ /darwin/)
        IN_ICON =  Sketchup.find_support_file('inside.pdf', 'Plugins/JWM_draw_angle_dim/Images')
        OUT_ICON = Sketchup.find_support_file('outside.pdf', 'Plugins/JWM_draw_angle_dim/Images')
      else
        IN_ICON =  Sketchup.find_support_file('inside.svg', 'Plugins/JWM_draw_angle_dim/Images')
        OUT_ICON = Sketchup.find_support_file('outside.svg', 'Plugins/JWM_draw_angle_dim/Images')
      end
    else
      IN_ICON =  Sketchup.find_support_file('interior2.png', 'Plugins/JWM_draw_angle_dim/Images')
      OUT_ICON = Sketchup.find_support_file('exterior2.png', 'Plugins/JWM_draw_angle_dim/Images')
    end

    IN_CURSOR = UI::create_cursor(IN_ICON, 0, 31)
    OUT_CURSOR = UI::create_cursor(OUT_ICON, 0, 31)

    def initialize
      # @ip is the InputPoint from the current pick
      @ip = Sketchup::InputPoint.new
      # @ip1 is the InputPoint from the previous pick
      # this is used as reference when @ip picks, which, in principle, should
      # cause the inference engine to favor points on the edge containing the
      # previous pick
      @ip1 = Sketchup::InputPoint.new

      @drawn = false

      # @pts[0] = first picked point
      # @pts[1] = picked vertex
      # @pts[2] = second picked point
      @pts = []

      # @state = 0 => waiting for first pick
      # @state = 1 => waiting for vertex pick
      # @state = 2 => waiting for second pick
      # @state = 3 => have three points, ready to draw
      @state = 0

      # radius for drawn arc can be calculated by default or input via VCB
      @user_radius = -1
      @radius = 0

      # tab key toggles between drawing inside and outside angle dimension
      @inside = true
      @cursor = IN_CURSOR
    end # def

    def show_status
      Sketchup::set_status_text (DangLH['arc radius']), SB_VCB_LABEL
      if(@radius != 0)
        Sketchup::set_status_text Sketchup.format_length(@radius), SB_VCB_VALUE
      else
        Sketchup::set_status_text "", SB_VCB_VALUE
      end
      case @state
      when 0
        Sketchup::set_status_text (DangLH['Point 1: first end of measured angle'])
        #      when 1
        #        Sketchup::set_status_text (DangLH['Point 2: vertex of measured angle'])
        #      when 2
        #        Sketchup::set_status_text (DangLH['Point 3: last end of measured angle'])
      end
    end # def

    # clear out all saved data from previous operation
    def reset
      @pts = []
      @state = 0

      @ip1.clear
      @drawn = false
      UI.set_cursor(@cursor)
      show_status
    end # def

    def activate
      reset
    end

    def deactivate(view)
      reset
      view.invalidate if @drawn
    end

    def set_current_point(x, y, view)
      case @state
      when 0
        # capture first end point
        @pts[0] = @ip.position
        # and cancel user's ability to rescale last drawn angle dim
        @drawn = false
      when 1
        # capture vertex point
        @pts[1] = @ip.position
        # tell the user what radius arc will be drawn, so they can change via VCB if desired
        length = @pts[0].distance @pts[1]
        if(@user_radius > 0)
          @radius = @user_radius
        else
          @radius = length/2.0
        end
      when 2
        # capture third point
        @pts[2] = @ip.position
      end
      show_status
    end

    # need this to cause inference point and tooltips to be drawn
    def onMouseMove(flags, x, y, view)
      @ip.pick(view, x, y, @ip1)
      view.invalidate
    end

    # draw the angle dimension info
    def draw_angle_dim
      model = Sketchup.active_model

      # make sure we are using the user's selected radius regardless of
      # which state this object was in when it was selected.
      if(@user_radius > 0)
        @radius = @user_radius
      end

      # make vectors from the user's input points.  These vectors point
      # out from the angle vertex along the two edges.  They are needed by
      # some subsequent methods that require directions for offsets, not
      # points
      vec1 = @pts[1].vector_to @pts[0]
      vec2 = @pts[1].vector_to @pts[2]

      # trap degenerate cases
      if(vec1.length == 0 or vec2.length == 0)
        UI.messagebox(DangLH['You must select three distinct points!'])
        reset
        return
      end
      if(vec1.parallel? vec2)
        UI.messagebox(DangLH['The selected lines are parallel, angle is 0 or 180'])
        reset
        return
      end

      # the angle bisector vector - used for placing the text
      bisector = (vec1+vec2)

      # scale the vectors to extend 1.5 the radius.  This will affect
      # the drawn edges.  The value 1.5 is arbitrary - change it if another
      # look is desired
      vec1.length = @radius * 1.5
      vec2.length = @radius * 1.5

      # bisector length controls text placement.  0.75 is arbitrary -
      # change it if another look is desired
      bisector.length = @radius * 0.75

      # find the angle between the vectors and the normal to their plane
      # this calculation should not explode, since we trapped the case of
      # parallel above (angle = 0 or 180), but the calculation of the normal
      # will be numerically unstable when angle is very small or very close to
      # 180.  I have tested at 0.1 degrees without problems.
      angle = vec1.angle_between vec2
      complement = 360.degrees - angle

      text = Sketchup.format_angle(angle) + "°"
      text2  = Sketchup.format_angle(complement) + "°"
      normal = (vec1 * vec2).normalize

      # this enables undo of the whole operation as a unit
      model.start_operation "Angular Dimension"

      # create a new group in which we will draw our dimension entities
      model_ents = model.active_entities
      group = model_ents.add_group
      if @inside
        group.name = "Angular Dimension (" + text + ")"
      else
        group.name = "Angular Dimension (" + text2 + ")"
      end
      ents = group.entities

      # add the angle edges to the group, scaled to the selected radius
      edge_pts = []
      edge_pts[0] = @pts[1].offset vec1
      edge_pts[1] = @pts[1]
      edge_pts[2] = @pts[1].offset vec2
      ents.add_edges edge_pts

      if(@inside)
        # interior angle mode
        # draw the arc across the angle at the selected radius
        arc = ents.add_arc @pts[1], vec1, normal, @radius, 0, angle, 30

        # draw the text and leader line
        # the leader connects to the center of the arc (it was drawn with 30 segments)
        leader_point = arc[15].start.position

        # note: the vector offset of the leader is 3D, which will cause the text to
        # "float" and remain legible as the view is orbited.  I haven't found a way to
        # lock the leader and text into the plane of the angle.
        t = ents.add_text text,leader_point,bisector
        t.leader_type = 1
      else
        # exterior angle mode
        arc2 = ents.add_arc @pts[1], vec1, normal, @radius, 0,-complement, 30
        leader_point2 = arc2[15].start.position
        t2 = ents.add_text text2,leader_point2,bisector.reverse
        t2.leader_type = 1
      end

      # tell undo the end of the bundled operation
      model.commit_operation

      #start over
      @drawn = true
      @state = 0
      show_status
    end

    # advance to the next state and set the status texts appropriately.
    def increment_state
      @state += 1
      case @state
      when 1
        # have first pick, ready for second
        # retain InputPoint as a hint for next
        @ip1.copy! @ip
        Sketchup::set_status_text (DangLH['Point 2: vertex of measured angle'])
      when 2
        # have second pick, ready for third
        # retain InputPoint as a hint for next
        @ip1.copy! @ip
        Sketchup::set_status_text (DangLH['Point 3: second end of measured angle'])
      when 3
        # have three picks, ready to draw the angle dimension
        draw_angle_dim
      end
    end

    # user clicks the mouse button - capture the data point and advance the state
    def onLButtonDown(flags, x, y, view)
      set_current_point(x, y, view)
      increment_state
    end

    def onCancel(flag, view)
      view.invalidate if @drawn
      reset
    end

    # accept user input in the VCB as the desired radius of the dimension arc
    def onUserText(text, view)
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

      @user_radius = value

      # redraw at new radius, if appropriate
      if @drawn
        # undo the previous operation before redrawing
        # this avoids buildup of obsolete operations on the
        # undo stack
        Sketchup.undo if @state==0
        draw_angle_dim
      end
    end

    # invoked by SketchUp when the view is invalidated.  This makes sure the
    # pick point and tooltip are visible.
    def draw(view)
      view.tooltip = @ip.tooltip
      @ip.draw view
    end

    def onSetCursor
      UI::set_cursor(@cursor)
    end

    # Toggle the drawing mode when the user presses TAB
    # on a PC or ALT on a Mac.
    # This method is inherently non-portable because one
    # can never be certain which keys are free to capture
    # vs previously assigned to some other purpose.
    def onKeyDown(key, rpt, flags, view)
      if(RUBY_PLATFORM =~ /darwin/)
        keycode = VK_ALT
      else
        keycode = 9
      end
      if key == keycode
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
    end

    # def onKeyUp(key, rpt, flags, view)
    # end

  end # class DrawAngleDimTool

  def self.draw_angle_dim_tool
    Sketchup.active_model.select_tool JWMPlugins::DrawAngleDimTool.new
  end

end # module
