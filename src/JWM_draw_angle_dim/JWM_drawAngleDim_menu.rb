# LanguageHandler added by Mario Chabot 2016. www.formation-sketchup.quebec
#=============================================================================
module JWMPlugins
  module AngularDim
    # used by the Command below to get a new instance of the Tool
    def self.draw_angle_dim_tool
      Sketchup.active_model.select_tool JWMPlugins::AngularDim::DrawAngleDimTool.new
    end
    
    if !file_loaded?(__FILE__)
      require_relative('JWM_drawAngleDim_logic.rb')
      cmd = UI::Command.new((DangLH['Angular Dimension (JWM)'])) {
        JWMPlugins::AngularDim::draw_angle_dim_tool
      }
      cmd.menu_text = (DangLH['Angular Dimension (JWM)'])
      if(Sketchup.version.to_i >= 16)
        if(RUBY_PLATFORM =~ /darwin/)
          cmd.small_icon = "Images/button.pdf"
          cmd.large_icon = "Images/button.pdf"
        else
          cmd.small_icon = "Images/button.svg"
          cmd.large_icon = "Images/button.svg"
        end
      else
        cmd.small_icon = "Images/ad16.png"
        cmd.large_icon = "Images/ad24.png"
      end
      UI.menu("Tools").add_item cmd

      toolbar = UI::Toolbar.new((DangLH['Angular Dimension (JWM)']))
      toolbar.add_item(cmd)
      toolbar.restore if toolbar.get_last_state==1
    end
    #-----------------------------------------------------------------------------
    file_loaded(__FILE__)
  end # AngularDim
end # JWMPlugins
