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
#
# This was extensively modified and enhanced from dim_angle.rb,
# Copyright 2005, Didier Bur, which, in turn, was based on the demo
# rectangle.rb by @Last Software
#
# Name:           draw_angle_dim
# Usage:          - Click 3 points, going around an angle in sequence from any point
#                 on one leg, to vertex, to any point on the other leg (clockwise or
#                 counterclockwise doesn't matter).  Be careful where you click -
#                 this tool lets the inference engine assist you but doesn't
#                 force you to click on existing model entities!
#                 - The tool will draw two edges along the sides of the angle,
#                 an arc across the angle, and a text with leader showing the
#                 value of the angle.  The two edges make it easy to realign
#                 the group with the original angle if the entity containing it is
#                 subsequently moved or rotated.
#                 - The primitive elements of each dimension are gathered into a Group
#                 named Angular Dimension (<angle>), where <angle> is the measured
#                 angle.  If you draw multiple angle dimensions, the <angle> value
#                 will help you identify which is which (unless, of course, you have
#                 several with the same value!).
#                 - Each Angular Dimension drawing is packaged in an operation, so that
#                 undo and redo treat all of the elements as a single step.
#                 - The default radius for the arc is half the distance between
#                 the first pick point and the vertex.  The user can override
#                 the radius by typing in the VCB at any time. If a new radius is entered
#                 before the first point is picked for the next angle, the prior
#                 dimension is redrawn at the new radius.  The user-selected
#                 radius remains in effect for additional angles until the
#                 user enters a new value or selects a different tool.
#                 - The TAB key (ALT on Mac) toggles between drawing the interior (<180) angle
#                 and drawing the exterior (>180) angle dimension.  If you press tab
#                 after an angle dimension is drawn but before picking the first
#                 point of the next angle, the current angle dimension will be
#                 redrawn in the new mode.
#                 - Unlike the built-in "smart" linear dimensions in SketchUp, the
#                 entities drawn by this tool are just graphics; they have no tie
#                 to the original angle and will not follow it or scale if it is
#                 modified.  You can open the Group for edit, but it is not likely
#                 you will like the results - it is easier to delete the dimension
#                 Group and do it again.
# Date:           December 23, 2011
# Type:           Tool
# Revisions:      - October 31, 2012 - Added code to detect Mac ("darwin") systems
#                 and change to ALT key instead of TAB to change modes when on Mac.
#                 Note: it seems that Macs do not like .png files created on a PC
#                 and will fail to show cursors unless using native files.  Strange!
#                 Makes one wonder about the "portable" in PNG!
#                 - Sept 7, 2013 - Enclose classes in my module.
#                 - Nov 23, 2015 - Adapt for SU 2016 signing and for vector-graphic cursors
#                 and toolbar buttons.
# Known Issues:   For some reason, the cursor does not appear on a Mac until the
#                 first time the user clicks after installing and activating the
#                 tool.  Subsequently it works fine, including if you quit and
#                 restart SketchUp.  This makes me think that on a Mac SU caches
#                 the cursors somewhere and doesn't get these until the tool is
#                 "really" active.
# LanguageHandler added by Mario Chabot 2016. www.formation-sketchup.quebec
#-----------------------------------------------------------------------------
require 'sketchup.rb'
require 'extensions.rb'
require 'langhandler.rb'

module JWMPlugins

  # Constant for language strings swapping...
  DangLH = LanguageHandler.new('draw_angle_dim.strings')

  # Load the extension.
  extension_name = DangLH['Draw_angle_dim']

  path = File.dirname(__FILE__).freeze
  loader = File.join(path, 'JWM_draw_angle_dim', 'JWM_drawAngleDim_menu.rb')
  extension = SketchupExtension.new(extension_name, loader)
  extension.description = (DangLH['Create an angle dimension with']) + "\n" +
                          (DangLH[' arc and text in a new group.'])
  extension.version = '4.01'
  extension.creator = 'Stephen Baumgartner and John McClenahan'
  extension.copyright = '2016, steve@slbaumgartner.com.'

  Sketchup.register_extension extension, true
puts "draw_angle_dim loaded"
end # module



