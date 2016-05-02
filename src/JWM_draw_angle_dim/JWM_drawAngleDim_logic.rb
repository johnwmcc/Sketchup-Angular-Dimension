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
# 3D text on dimensioned angle plane added by John McClenahan 2016 john.mcclenahan@gmail.com
#-----------------------------------------------------------------------------

##++JWM Logic version history
#      v4.14 - Filled text black, and lifted it 0.005 * @radius off dimension plane to reduce z-fighting if on face.
#                 Have also filled closed arrow black, but left it on surface. Lifting it disp lays poorly from some angles
#                 - noticeably out of line with arc end.
#                 Could perhaps stop arc short at middle of arrowhead for closed arrow only?
#                 Added right angle lines, and hid arcs, arrowheads and text for right angles. Not sure how to scale
#                   the lines, and/or whether to keep text displayed instead of hidden
#      v4.13 - Arrowhead now selectable simply by changing value of @arrow_style in initialize function
#                 (but may need to restart SU?)
#      v4.12 - Outside angles working properly, including text angle
#      v4.11 - Outside angle arcs and arrowheads correctly drawn, and text correctly placed but incorrectly oriented wrt screen
#      v4.10 - Text that won't fit in dimension angle correctly positioned and oriented, AND you can choose which side of the angle
#                 external text for small angles is put - it goes at the first picked end
#      v4.09 - Text that won't fit in dimension angle now correctly positioned and oriented at start
#                 though I can't understand quite why it needs 90 deg different rotation from text inside angle
#      v4.08 - Moved make_arrowhead into a function, and reordered some of the steps for future use
#      v4.07 - tests whether whole dimension, only text, or neither, will fit inside dimension lines
#              and puts arrows and if necessary text, outside dimension lines.
#              Have still to rename vector to text position, to get the orientation of text correct on screen after move to vertex
#
#      v4.06 - senses dimension angle bisector relative to screen orientation,
#              and rotates text accordingly in 90 degree increments.
#              Removed text fill, which caused Z-fighting. Removed test display of angle bisector
#
#      v4.05 - now sensing direction of vertex relative to screen - using view.screen_coords, and rotating text 180 degrees if nec.
#      v4.04 - partially working detection of direction of vertex, to rotate text if needed
#      v4.03 - working with SLB transformation matrix, and three arrow styles implemented. Text can still be upside down
#      v4.02 - partially working
#      v4.01 - SLB code adapted for namespace change to JWM - works except not finding Images and Resources
#              but works if those folders are placed in Plugins in a folder JWM_draw_angle_dim
##---JWM
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
#-----------------------------------------------------------------------------
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
##+++JWM
    # Text size as a fraction of @radius - default, 0.1. Or user can set fixed height
        @user_text_height = -1
        @text_scale = 0.05
    # Dimension line scale as fraction of radius
        @dim_line_scale = 1.05
    # Arrowhead length as fraction of @radius
        @arrow_scale = 0.05
    # Arc segments for dimension arcs
        @arc_segments = 12
    # Arrow style closed, open, slash, dot or none?
      @arrow_style = "open"
  #Create arrowheads if that hasn't already been done
      if !dim_angle_arrow = Sketchup.active_model.definitions["dim_angle_arrow"]
        dim_angle_arrow = Sketchup.active_model.definitions.add("dim_angle_arrow")
      end

      styles = ["closed", "open", "slash", "dot", "none"]
      styles.each{ |arrow_style|
        make_arrowhead(arrow_style, dim_angle_arrow)
        }
      use_arrowhead(@arrow_style,dim_angle_arrow)
##---JWM
      # tab key toggles between drawing inside and outside angle dimension
      @inside = true
      @cursor = IN_CURSOR
    end # initialize
#-----------------------------------------------------------------------------
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
#-----------------------------------------------------------------------------
    # clear out all saved data from previous operation
    def reset
      @pts = []
      @state = 0

      @ip1.clear
      @drawn = false
      UI.set_cursor(@cursor)
      show_status
    end # def
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
##+++JWM
          @radius = length # was length/2.0
##---JWM
        end
      when 2
        # capture third point
        @pts[2] = @ip.position
      end
      show_status
    end
#-----------------------------------------------------------------------------
    # need this to cause inference point and tooltips to be drawn
    def onMouseMove(flags, x, y, view)
      @ip.pick(view, x, y, @ip1)
      view.invalidate
    end
#-----------------------------------------------------------------------------
#+++JWM
    def make_arrowhead(arrow_style, arrowhead)
    # arrow_style - text "closed", "open", "slash",  "dot" or "none"
    # arrowhead - an empty component definition object

    # Draw an arrowhead component
      arrow_points = Array.new ;
      arrow_points[0] = [1.0, -0.3, 0]
      arrow_points[1] = ORIGIN ; # "ORIGIN" is a SU provided constant
      arrow_points[2] = [1.0,  0.3, 0]

      case arrow_style # Set in initialize as closed, open, line, dot or none

      when "closed"
        if !@dim_angle_aro_closed = Sketchup.active_model.definitions["dim_angle_aro_closed"]
          @dim_angle_aro_closed = Sketchup.active_model.definitions.add("dim_angle_aro_closed")
        end
        arrow_face = @dim_angle_aro_closed.entities.add_face(arrow_points)
        # If the  blue face is pointing up, reverse it.
        arrow_face.reverse! if arrow_face.normal.z < 0  # flip face to up if facing down
        # Fill arrowhead, and move it up slightly to avoid z-fighting on a face
        arrow_face.material = "black"
      when "open"
        if !@dim_angle_aro_open = Sketchup.active_model.definitions["dim_angle_aro_open"]
          @dim_angle_aro_open = Sketchup.active_model.definitions.add("dim_angle_aro_open")
        end
        arrow_lines = @dim_angle_aro_open.entities.add_edges arrow_points

      when "slash"
        if !@dim_angle_aro_slash = Sketchup.active_model.definitions["dim_angle_aro_slash"]
          @dim_angle_aro_slash = Sketchup.active_model.definitions.add("dim_angle_aro_slash")
        end
        arrow_points[0] = [0.5, -0.5, 0]
        arrow_points[1] = ORIGIN
        arrow_points[2] = [-0.5,  0.5, 0]
        arrow_lines = @dim_angle_aro_slash.entities.add_edges arrow_points

      when "dot"
        if !@dim_angle_aro_dot = Sketchup.active_model.definitions["dim_angle_aro_dot"]
          @dim_angle_aro_dot = Sketchup.active_model.definitions.add("dim_angle_aro_dot")
        end
        arrow_dot = @dim_angle_aro_dot.entities.add_circle([0,0,0], Z_AXIS, 0.1, 12)
        arrow_face = @dim_angle_aro_dot.entities.add_face(arrow_dot)

      when "none"
        if !@dim_angle_aro_none = Sketchup.active_model.definitions["dim_angle_aro_none"]
          @dim_angle_aro_none = Sketchup.active_model.definitions.add("dim_angle_aro_none")
        end
        # have to have something in the component to allow it to be created (I think)
        # You can turn guides off, or maybe I can make this hidden?
        arrow_lines = @dim_angle_aro_none.entities.add_cpoint arrow_points[1]

      else
        UI.messagebox "Sorry that #{arrow_style} is not a valid arrow type. \nPlease edit the script and initialize @arrow_style"
        return false
      end #case

      return arrowhead

        # To add the component directly to the model, you have to define a transformation. We can define
        # a transformation that does nothing to just get the job done.
        # trans = Geom::Transformation.new  # an empty, default transformation.
        # arro_comp_inst = Sketchup.active_model.active_entities.add_instance(dim_angle_arrow, trans)
    end # make_arrowhead
#-----------------------------------------------------------------------------
    def use_arrowhead(arrow_style, arrowhead)
      case arrow_style
      when "closed"
        arrowhead = @dim_angle_aro_closed
      when "open"
        arrowhead = @dim_angle_aro_open
      when "slash"
        arrowhead = @dim_angle_aro_slash
      when "dot"
        arrowhead = @dim_angle_aro_dot
      when "none"
        arrowhead = @dim_angle_aro_none
      else
        UI.messagebox "Sorry that #{arrow_style} is not a valid arrow type. \nPlease edit the script and initialize @arrow_style"
      end # case arrow_style
      return arrowhead
    end # use_arrowhead
#-----------------------------------------------------------------------------

    def space_for_text(angle, radius, text_rotn, text_bb_center, text_bb_width, text_bb_height)
      space_for_text = 2.0 * Math::atan(0.5*text_bb_width/@radius)
    end


#---JWM

#-----------------------------------------------------------------------------
# draw the angle dimension info
    def draw_angle_dim
      model = Sketchup.active_model

##JWM note. It would be good to remember @radius for whole SU session, not just one use of the tool

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
##+++JWM
      # scale the vectors to extend the radius a little.  This will affect
      # the drawn edges.  The value is arbitrary - change @dim_line_scale in
      # def initialize if another look is desired
      vec1.length = @radius * @dim_line_scale
      vec2.length = @radius * @dim_line_scale

      # the angle bisector vector - used for placing the text
      # unless angle is too small
      bisector = (vec1+vec2)

      # bisector length controls text placement - to centre text on arc,
      # needs to be at radius
      bisector.length = @radius



##---JWM

      # find the angle between the vectors and the normal to their plane
      # this calculation should not explode, since we trapped the case of
      # parallel above (angle = 0 or 180), but the calculation of the normal
      # will be numerically unstable when angle is very small or very close to
      # 180.  I (SLB) have tested at 0.1 degrees without problems.
      angle = vec1.angle_between vec2
      complement = 360.degrees - angle

  # Set text depending on inside or outside angle chosen
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

##+++SLB
      ## Adjust direction of normal, and order of vec1, vec2, in relation to view angle
      ## so the dimension goes into the picked points the right way round
        camera = Sketchup.active_model.active_view.camera
        view_dir = camera.direction
        dot = normal.dot view_dir
        ccw = dot > 0
       # puts "dot = #{dot}, ccw = #{ccw}"
        if ccw
          normal.reverse!
          temp=vec1
          vec1=vec2
          vec2=temp
        end
##---SLB

      # add the angle edges to the group, scaled to the selected radius
#       edge_pts = []
#       edge_pts[0] = @pts[1].offset vec1
#       edge_pts[1] = @pts[1]
#       edge_pts[2] = @pts[1].offset vec2

##+++JWM
      #ents.add_edges edge_pts
      # To see where the pick points were:
#         model = Sketchup.active_model
#       model_ents = model.entities
#         model_ents.add_cpoint @pts[0]
#         model_ents.add_cpoint @pts[2]
#       angle_edges = model_ents.add_edges edge_pts
#       if angle_edges
#         face = angle_edges[0].common_face angle_edges[1]
#         if face
#           # find and display face normal
#           face_normal = face.normal
#           same = face_normal.normalize = normal.normalize
#           puts "face.normal and picked plane normal same? = #{same}"
#          model_ents.add_edges face.normal
 #         model_ents.add_cpoint
#        end
#      end
#       Temporarily add edge for normal to and bisector of dimension lines
#       edge_normal = []
#       edge_normal[0] = @pts[1]
#       edge_normal[1] = @pts[1].offset normal
#      model = Sketchup.active_model
#      modelents = model.entities
#      modelents.add_edges edge_normal
#      model_ents.add_cpoint edge_normal[1]

       edge_bisector = []
       edge_bisector[0] = @pts[1]
       edge_bisector[1] = @pts[1].offset bisector

      #model_ents.add_edges edge_bisector.to_a
      #model_ents.add_cpoint edge_bisector[1].to_a



        ## Draw angle text in 3D text, inside a group, at the origin
          # Parameters are string, alignment, font name, is_bold (Boolean), is_italic (Boolean),
          #   letter_height, tolerance, z, is_filled (Boolean), extrusion
          # You could set the Z plane for the text a small amount up, to avoid z-fighting with any face it's drawn over,
          #   but it's hard to see what level to put it at, so zero for the moment. [And in any case, any non-zero value
          #   is overwritten by the move]
          # Could also move text_group as a whole up - may try that later

          text_group = ents.add_group
          if !@inside
            text = text2
          end
          t = text_group.entities.add_3d_text text, TextAlignLeft, "Arial", false, false, @text_scale*@radius, 0, 0, true, 0.0
          # Colo(u)r the text black (optional - can cause Z-fighting in display)
          text_group.material = "black"

          # Find the centre, width and height of the text group from its bounding box (bb_height may be bigger than letter_height)
          text_bb_center = text_group.local_bounds.center
          text_bb_width = text_group.local_bounds.width
          text_bb_height = text_group.local_bounds.height


          # Oversimple calculation leaves room for text in any orientation, but sometimes too much room
          # text_gap_angle = 2.0 * Math::atan(0.5*text_bb_width/@radius)

          text_gap_angle = space_for_text(angle, @radius, nil, text_bb_center, text_bb_width, text_bb_height)
          # puts text_gap_angle.radians.round(1).to_s


          # Put in angle delimiter lines at origin
          ents.add_edges [@dim_line_scale*@radius, 0, 0], ORIGIN
          ents.add_edges ORIGIN, [@dim_line_scale*@radius*Math::cos(angle), @dim_line_scale*@radius*Math::sin(angle), 0]

          ## Scale the arrowheads to desired size
          arrow_size_scale = Geom::Transformation.scaling @arrow_scale*@radius
          # puts "arrow arrow_size_scale = #{@arrow_scale*@radius}"

##---JWM

      if(@inside)
        # interior angle mode

##---JWM Main mods statt here
        # draw the arc across the angle at the selected radius
        #arc = ents.add_arc @pts[1], vec1, normal, @radius, 0, angle, 30

## To get text orientation and placement correct, we first have to work out where it would go, before drawing anything

      #----------------- Work out where to put text

          ## Work out how to draw dimension arc in two parts to leave a gap for the dimension text
          ## Might want to make the gap just a little bigger than text width, if text aligns with arc,
          ## but for the moment, leave it at width


        ## Draw the arcs, arrowheads and text all at the origin first,
        ## then move all at once to dimensioned angle

        ## First work out if the arcs, text and arrowhead will fit inside the dimension lines
        ## Allow an extra half-arrowhead length for a minimal  partial arc at each end
          arrowhead_angle = 2.0 * Math::atan(@arrow_scale)
          if 2 * arrowhead_angle + text_gap_angle < angle # then angular dimension will fit inside dimension lines
            dim_will_fit = true
          end

      #----------------- Draw arcs
        #  Draw the arcs, number of segments as specified in initialize function
          # parameters are centerpoint, X-axis, normal, radius, start angle, end angle
          arcs_group = ents.add_group
          arc_ents = arcs_group.entities
          if dim_will_fit
            text_will_fit = true
            arc1 = arc_ents.add_arc ORIGIN, X_AXIS, Z_AXIS, @radius, 0, 0.5*(angle - text_gap_angle), @arc_segments
            arc2 = arc_ents.add_arc ORIGIN, X_AXIS, Z_AXIS, @radius, 0.5*(angle + text_gap_angle), angle, @arc_segments
          else
            arc1 = arc_ents.add_arc ORIGIN, X_AXIS, Z_AXIS, @radius, 0, - arrowhead_angle, 4
            arc2 = arc_ents.add_arc ORIGIN, X_AXIS, Z_AXIS, @radius, angle + arrowhead_angle, angle, 4
            # See if text will fit, even though whole dimension won't
            if 1.05*text_gap_angle < angle
              text_will_fit = true
            end
          end



      #----------------- Calculate transforms to put dimensions in the right place
        ## Have to calculate all the transforms first, to insert component instance in the right place



      #----------------- Will dimension arrows fit between dimension lines?
        ## Rotate the arrowheads to line up with start and end of arc
        if dim_will_fit
          arrow1_rotn = 90.degrees
          arrow2_rotn = angle - 90.degrees
        else
          arrow1_rotn = -90.degrees
          arrow2_rotn = 90.degrees + angle
        end

        arrow1_rotate = Geom::Transformation.rotation ORIGIN, Z_AXIS, arrow1_rotn
        arrow2_rotate = Geom::Transformation.rotation ORIGIN, Z_AXIS, arrow2_rotn

        # Move to start/end of arcs and raise slightly if closed arrowhead style
        arrow1_move = Geom::Transformation.translation ORIGIN.vector_to arc1[0].start.position
        arrow2_move = Geom::Transformation.translation ORIGIN.vector_to arc2[-1].end.position

 #       if !dim_angle_arrow = Sketchup.active_model.definitions["dim_angle_arrow"]
           dim_angle_arrow = use_arrowhead(@arrow_style, dim_angle_arrow)
#        end

        # Combine transformations to insert an arrowhead at start and end of arcs
          arrow1 = arc_ents.add_instance dim_angle_arrow, arrow1_move*arrow1_rotate*arrow_size_scale
          arrow2 = arc_ents.add_instance dim_angle_arrow, arrow2_move*arrow2_rotate*arrow_size_scale

      #-----------------
      # Check if right angle
      if angle <= 90.01.degrees && angle >= 89.99.degrees # Check if right angle (== 90.degrees doesn't work)
            # Draw two straight lines at right angles at vertex
            # Calculate scale factor to get the lines proportional to gap between vertex and edge of text
            ra_scale = 0.67*@radius - 0.5*text_bb_width
            right_angle = []
            right_angle[0] = [ra_scale,0,0]
            right_angle[1] = [ra_scale,ra_scale,0]
            right_angle[2] = [0,ra_scale,0]
            ents.add_edges right_angle
        # hide arcs, arrowheads (?and text)

          arcs_group.hidden= true

          arrow1.hidden= true
          arrow2.hidden= true

          text_group.hidden= true
      end
      #-----------------  Will text fit between dimension lines?
        if text_will_fit
          #  Move the center of the text to the center of the dimension arc ...
          text_center = Geom::Point3d.new [@radius*Math::cos(0.5*angle), @radius*Math::sin(0.5*angle),0]
          #puts "text_center = " + text_center.to_s
          # ents.add_cpoint text_center
        # Move text to text center, and lift text slightly above dimension plane, to avoid z-fighting if on a face
          text_posn = text_center - text_bb_center + [0, 0, 0.005*@radius]
          text_group.move! text_posn
        # ... and rotate it in line with middle of arc
        # puts "normal = " + normal.to_s

            text_rotn1 = 0.5*angle - 90.degrees

        else # text won't fit - have to put it outside dimension, as well as the arcs and arrowheads
        #  Move the center of the text outside the dimension arc ...
          if !ccw # points were picked clockwise. Put arc at start

            text_center = Geom::Point3d.new [@radius*Math::cos(0.5*text_gap_angle + arrowhead_angle), -@radius*Math::sin(0.5*text_gap_angle + arrowhead_angle),0]
            #puts "text_center = " + text_center.to_s
          else # ccw
          # or at the other end of the dimension arc (counterclockwise from start)
            text_center = Geom::Point3d.new [@radius*Math::cos(angle + 0.5*text_gap_angle + arrowhead_angle), @radius*Math::sin(angle + 0.5*text_gap_angle + arrowhead_angle),0]
          end #if ccw
          # ents.add_cpoint text_center

          text_posn = text_center - text_bb_center
          text_group.move! text_posn + [0, 0, 0.005*@radius]

        # ... and rotate it in line with the arc
        # puts "normal = " + normal.to_s
          if !ccw
            text_rotn1 = -(0.5*text_gap_angle + arrowhead_angle)
          else #at end
            text_rotn1 = angle + 0.5*text_gap_angle + arrowhead_angle
          end
        end # if text_will_fit

          text_rotate1 = Geom::Transformation.rotation text_center, Z_AXIS , text_rotn1
          text_group.transform! text_rotate1

          ## Temporarily add normal vector to dimensions - up the Z_AXIS
          ##ents.add_edges ORIGIN, [0,0,0.5*@radius]
          ## ... and a cpoint at its end
          ##ents.add_cpoint [0,0,0.5*@radius]


      #----------------- Work out orientation of dimension and text placement in relation to screen view at time of placement.

##+++JWM
            # Check orientation of text_posn relative to vertex, in camera's view.
            # Returned values are X from left to right (in pixels, approximately) and
            #   Y values measured from TOP to BOTTOM (reverse of normal Y axis direction)
            view = Sketchup.active_model.active_view
            pt_vertex = view.screen_coords @pts[1]
            # Calculate final text position near vertex from angle bisector, and rotation if text is outside dimension
            if text_will_fit
              pt_text_center = edge_bisector[1]
            else
              # Text is rotated outside dimension lines - recalculate where text center will be after dimension group is relocated to vertex
              transform_text_center = Geom::Transformation.rotation @pts[1], normal,  -0.5*(angle + text_gap_angle)
              pt_text_center = edge_bisector[1].transform transform_text_center
            end

            pt_text_posn = view.screen_coords pt_text_center
            # puts "text position screen coords = #{pt_text_posn.x.to_int}, #{pt_text_posn.y.to_int}"

            # Now calculate which quadrant the vertex-to-text-centre line appears to be in the current view, and
            #   rotate text accordingly to keep it mostly upright
            diff_x = (pt_text_posn.x - pt_vertex.x)
            diff_y = (pt_text_posn.y - pt_vertex.y)

            if diff_y < 0 && diff_y.abs > diff_x.abs # vertex to text center points in northerly quadrant (angle between +45  and +135 degrees)
               # no rotation required
              rotation = 0.degrees
#              puts "northerly"
            end

            if diff_x < 0 && diff_y.abs <= diff_x.abs # vertex to text center points in westerly quadrant (angle between +135 and -135)
              rotation = - 90.degrees
#              puts "westerly"
            end
            if diff_y >= 0 && diff_y.abs > diff_x.abs # vertex to text center points in southerly quadrant (angle between -45 and -135)
              rotation = 180.degrees
#              puts "southerly"
            end

            if diff_x >= 0 && diff_y.abs <= diff_x.abs #  vertex to text center points in easterly quadrant (angle between +135 and -135)
              rotation = 90.degrees
#              puts "easterly"
            end

          if !text_will_fit
            rotation = rotation - 90.degrees
          end

          # perform text rotation to keep it mostly upright when moved to dimension angle
            text_rotate2 = Geom::Transformation.rotation text_center, Z_AXIS, rotation
            text_group.transform! text_rotate2

##---JWM

#=========================
      else  # we're dimensioning an exterior angle

        # Draw arcs
          dim_will_fit = true
          text_will_fit = true

        # Double the arc segments for outside angles to give smoother arcs
          arc1 = ents.add_arc ORIGIN, X_AXIS, Z_AXIS, @radius, 0, - 0.5*(complement - text_gap_angle), 2*@arc_segments
          arc2 = ents.add_arc ORIGIN, X_AXIS, Z_AXIS, @radius, - 0.5*(complement + text_gap_angle),  - complement, 2*@arc_segments

        # Draw arrowheads
          arrow1_rotn = -90.degrees
          arrow2_rotn = 90.degrees + angle

          arrow1_rotate = Geom::Transformation.rotation ORIGIN, Z_AXIS, arrow1_rotn
          arrow2_rotate = Geom::Transformation.rotation ORIGIN, Z_AXIS, arrow2_rotn
          arrow1_move = Geom::Transformation.translation ORIGIN.vector_to arc1[0].start.position
          arrow2_move = Geom::Transformation.translation ORIGIN.vector_to arc2[-1].end.position

        # Combine transformations to insert an arrowhead at start and end of arcs

          dim_angle_arrow = use_arrowhead(@arrow_style, dim_angle_arrow)

          arrow1 = ents.add_instance dim_angle_arrow, arrow1_move*arrow1_rotate*arrow_size_scale
          arrow1 = ents.add_instance dim_angle_arrow, arrow2_move*arrow2_rotate*arrow_size_scale

      #  Move the center of the text to the center of the dimension arc ...
          text_center = Geom::Point3d.new [@radius*Math::cos(0.5*complement), -@radius*Math::sin(0.5*complement),0]
          #puts "text_center = " + text_center.to_s
          ents.add_cpoint text_center
          text_posn = text_center - text_bb_center + [0, 0, 0.005*@radius]
          text_group.move! text_posn
        # ... and rotate it in line with middle of arc
        # puts "normal = " + normal.to_s
          text_rotn1 =  0.5*angle + 90.degrees
          text_rotate1 = Geom::Transformation.rotation text_center, Z_AXIS , text_rotn1
          text_group.transform! text_rotate1

##+++JWM
            # Check orientation of text_posn relative to vertex, in camera's view.
            # Returned values are X from left to right (in pixels, approximately) and
            #   Y values measured from TOP to BOTTOM (reverse of normal Y axis direction)
            view = Sketchup.active_model.active_view
            pt_vertex = view.screen_coords @pts[1]
            # Calculate final text position near vertex from angle bisector, and rotation if text is outside dimension
            if text_will_fit
              pt_text_center = edge_bisector[1]
            else
              # Text is rotated outside dimension lines - recalculate where text center will be after dimension group is relocated to vertex
              transform_text_center = Geom::Transformation.rotation @pts[1], normal,  -0.5*(angle + text_gap_angle)
              pt_text_center = edge_bisector[1].transform transform_text_center
            end

            pt_text_posn = view.screen_coords pt_text_center
            # puts "text position screen coords = #{pt_text_posn.x.to_int}, #{pt_text_posn.y.to_int}"

            # Now calculate which quadrant the vertex-to-text-centre line appears to be in the current view, and
            #   rotate text accordingly to keep it mostly upright
            diff_x = (pt_text_posn.x - pt_vertex.x)
            diff_y = (pt_text_posn.y - pt_vertex.y)

            if diff_y < 0 && diff_y.abs > diff_x.abs # vertex to text center points in northerly quadrant (angle between +45  and +135 degrees)
              rotation = -180.degrees
#              puts "northerly"
            end # if

            if diff_x < 0 && diff_y.abs <= diff_x.abs # vertex to text center points in westerly quadrant (angle between +135 and -135)
              rotation = 90.degrees
#              puts "westerly"
            end

            if diff_y >= 0 && diff_y.abs > diff_x.abs # vertex to text center points in southerly quadrant (angle between -45 and -135)
              rotation = 0.degrees
#              puts "southerly"
            end

            if diff_x >= 0 && diff_y.abs <= diff_x.abs #  vertex to text center points in easterly quadrant (angle between +135 and -135)
              rotation = -90.degrees
#              puts "easterly"
            end

            text_rotate2 = Geom::Transformation.rotation text_center, Z_AXIS, rotation
            text_group.transform! text_rotate2
      end # if @inside/else outside angle

##---JWM

##+++SLB
      #----------------- Calculate overall transformation to move dimension group to picked vertex in correct orientation
            # Unit vectors for where we want the x,y,z axes of the group drawn
            #   at the origin to end up
            newx = vec1.normalize
            newz = normal
            newy = newz.cross(newx).normalize

            # use the normal vectors to build a transformation matrix
            trans_array = []
            trans_array[0] = newx[0]
            trans_array[1] = newx[1]
            trans_array[2] = newx[2]
            trans_array[3] = 0.0
            trans_array[4] = newy[0]
            trans_array[5] = newy[1]
            trans_array[6] = newy[2]
            trans_array[7] = 0.0
            trans_array[8] = newz[0]
            trans_array[9] = newz[1]
            trans_array[10] = newz[2]
            trans_array[11] = 0.0
            trans_array[12] = @pts[1][0]
            trans_array[13] = @pts[1][1]
            trans_array[14] = @pts[1][2]
            trans_array[15] = 1.0

            trans_from_array = Geom::Transformation.new trans_array
            group.transform! trans_from_array

##---SLB

##---JWM


      # tell undo the end of the bundled operation
      model.commit_operation

      #start over
      @drawn = true
      @state = 0
      show_status
  end # draw_angle_dim
#-----------------------------------------------------------------------------
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
    end # increment_state
#-----------------------------------------------------------------------------
    # user clicks the mouse button - capture the data point and advance the state
    def onLButtonDown(flags, x, y, view)
      set_current_point(x, y, view)
      increment_state
    end
#-----------------------------------------------------------------------------
    def onCancel(flag, view)
      view.invalidate if @drawn
      reset
    end
#-----------------------------------------------------------------------------
    # accept user input in the VCB as the desired radius of the dimension arc
    def onUserText(text, view)
      # The user may type in something that we can't parse as a length
      # so we set up some exception handling to trap that
      begin
        value = text.to_l
      rescue
        # Error parsing the text
        UI.messagebox("please enter a valid length value for arc radius")
        value = nil
        Sketchup::set_status_text "", SB_VCB_VALUE
      end
      if(value <= 0.0)
        UI.messagebox("arc radius must be a positive length value")
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
#-----------------------------------------------------------------------------
    # invoked by SketchUp when the view is invalidated.  This makes sure the
    # pick point and tooltip are visible.
    def draw(view)
      view.tooltip = @ip.tooltip
      @ip.draw view
    end
#-----------------------------------------------------------------------------
    def onSetCursor
      UI::set_cursor(@cursor)
    end
#-----------------------------------------------------------------------------
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
#-----------------------------------------------------------------------------
    # def onKeyUp(key, rpt, flags, view)
    # end

  end # class DrawAngleDimTool
#-----------------------------------------------------------------------------
  def self.draw_angle_dim_tool
    Sketchup.active_model.select_tool JWMPlugins::DrawAngleDimTool.new
  end

end # module
